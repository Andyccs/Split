// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Split
 * @dev Split contract allows users to create SplitProposal. A SplitProposal contains an array of
 * payers, and the amounts that are required to be paid by each payer. Once all payers have paid the
 * required amounts (by calling the sendAmount() method), any receiver can initiate a
 * sendToReceiver() call to send all amounts paid by all the payers to the receiver and mark the
 * SplitProposal as completed. Before a SplitProposal is marked as completed, any payer can call
 * withdrawAmount() to withdraw the amount that payer has already paid for the SplitProposal.
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract Split is Ownable {

    // SplitProposal contains an array of payers and the amounts that are required to by paid by
    // each payer, before the total amount is sent to the receiver.
    struct SplitProposal {
        // payers is a list of payer addresses that are required to pay the specified amount (as
        // indicated by the "payerAmounts" variable below) before a SplitProposal can be marked as
        // completed. payers is one of the input arguments of createSplitProposal() method.
        address[] payers;

        // payerAmounts is a list of amounts that need to be paid by each payer, i.e. payers[i]
        // should pay payerAmounts[i] for all i < payerAmounts.length, before a SplitProposal can be
        // marked as completed. payerAmounts is one of the input arguments of createSplitProposal()
        // method.
        uint256[] payerAmounts;

        // receivers is a list of receiver addresses to receive the specified amount (as indicated
        // by the "receiverAmounts" variable below) after a SplitProposal is marked as completed.
        // Note that there is no restriction on who is the receiver, and it is possible for a
        // receiver to be one of the payer.
        address[] receivers;

        // receiverAmounts is a list of amounts that need to be paid to each receiver, i.e.
        // receivers[i] should receive receiverAmounts[i] for all i < receiverAmounts.length, when a
        // SplitProposal is marked as completed. receiverAmounts is one of the input arguments of
        // createSplitProposal() method.
        uint256[] receiverAmounts;

        // isPayer is an index of whether a given payer address is a valid payer for a
        // SplitProposal. This index is created during createSplitProposal() and should never be
        // changed after that.
        mapping(address => bool) isPayer;

        // isReceiver is an index of whether a given receiver address is a valid receiver for a
        // SplitProposal. This index is created during createSplitProposal() and should never be
        // changed after that.
        mapping(address => bool) isReceiver;

        // payerAmountsByAddress is an index of payer address to the amount that is required to be
        // paid by the payer. This index is created during createSplitProposal() and should never be
        // changed after that.
        mapping(address => uint256) payerAmountsByAddress;

        // receiverAmountsByAddress is an index of receiver address to the amount that is required
        // to be paid to the receiver. This index is created during createSplitProposal() and should
        // never be changed after that.
        mapping(address => uint256) receiverAmountsByAddress;

        // totalAmount is the sum of "payerAmounts" or the sum of "receiverAmounts". This value is
        // created during createSplitProposal() and should never be changed after that.
        uint256 totalAmount;

        // paidByAddress tracks whether a payer address has already made the required payment. The
        // value of this mapping is set to true when sendAmount() is called successfully. The value
        // of this mapping is set to false when withdrawAmount() is called successfully.
        mapping(address => bool) paidByAddress;

        // withdrawByAddress tracks whether a receiver address has withdraw the payment. The value
        // of this mapping is set to true when receiverWithdrawAmount() is called successfully.
        mapping(address => bool) withdrawByAddress;

        // Whether this SplitProposal has completed. This field is set to true by sendToReceiver()
        // if the method completed successfully. Once a SplitProposal is completed, it is no longer
        // possible for payer to interact with the SplitProposal, and receiver can start withdraw
        // amounts from this SplitProposal.
        bool completed;
    }

    // All SplitProposals
    mapping (uint256 => SplitProposal) private proposals;

    // All valid SplitProposals
    mapping (uint256 => bool) public validProposals;

    // The next proposal index that is going to be used in createSplitProposal()
    uint256 public nextProposalIndex;

    // Any tips that can be claimed by the owner. Extra amounts that are sent by payers using
    // sendAmount() to this contract are tracked by this variable, and these extra amounts are
    // considered tips for the owner.
    uint256 public claimableTips;

    // Whether the given proposalNumber is valid.
    modifier validProposalNumber(uint256 proposalNumber) {
        require(validProposals[proposalNumber], "Invalid proposalNumber");
        _;
    }

    constructor() Ownable() {
    }

    // Function to receive Ether.
    receive() external payable {
        claimableTips += msg.value;
    }

    // Function to receive Ether.
    fallback() external payable {
        claimableTips += msg.value;
    }

    /**
     * @dev Creates a SplitProposal
     * @param payers An array of payers that need to pay the given amounts
     * @param payerAmounts An array of amounts that needs to be paid by each payer
     * @param receivers An array of receivers to be paid
     * @param receiverAmounts An array of amounts to be received by each receiver
     * @return The SplitProposal number
     */
    function createSplitProposal(
        address[] memory payers,
        uint256[] memory payerAmounts,
        address[] memory receivers,
        uint256[] memory receiverAmounts
    )
        public
        returns (uint256)
    {
        require(payers.length != 0, "No payer address is provided");
        require(
            payers.length == payerAmounts.length,
            "The length of payers and payerAmounts must be the same"
        );
        require(
            receivers.length == receiverAmounts.length,
            "The length of receivers and receiverAmounts must be the same"
        );
        require(
            payers.length == receivers.length,
            "The length of payers and receivers must be the same"
        );
        require(validProposals[nextProposalIndex] == false, "nextProposalIndex is already used");

        validProposals[nextProposalIndex] = true;
        SplitProposal storage proposal = proposals[nextProposalIndex];
        proposal.payers = payers;
        proposal.payerAmounts = payerAmounts;
        proposal.receivers = receivers;
        proposal.receiverAmounts = receiverAmounts;

        uint256 totalPayerAmounts;
        uint256 totalReceiverAmounts;
        for (uint256 i = 0; i < payers.length; i++) {
            require(payers[i] != address(0), "payer account is the zero address");
            require(receivers[i] != address(0), "receiver account is the zero address");
            require(
                proposal.isPayer[payers[i]] == false,
                "A payer exist more than once in payers input argument"
            );
            require(
                proposal.isReceiver[receivers[i]] == false,
                "A receiver exist more than once in receivers input argument"
            );
            proposal.isPayer[payers[i]] = true;
            proposal.isReceiver[receivers[i]] = true;
            proposal.payerAmountsByAddress[payers[i]] = payerAmounts[i];
            proposal.receiverAmountsByAddress[receivers[i]] = receiverAmounts[i];
            totalPayerAmounts += payerAmounts[i];
            totalReceiverAmounts += receiverAmounts[i];
        }
        require(
            totalPayerAmounts == totalReceiverAmounts,
            "sum(payerAmounts) != sum(receiverAmounts)"
        );
        proposal.totalAmount = totalPayerAmounts;
        return nextProposalIndex++;
    }

    /**
     * @dev Payer sends the required amount to a specific SplitProposal (as indicated by
     * "proposalNumber" input argument). If payer is not a valid payer, not sending enough amount,
     * or already paid for the SplitProposal, the transaction is reverted.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function sendAmount(uint256 proposalNumber) public payable validProposalNumber(proposalNumber) {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.completed == false, "The proposal is already completed");
        require(proposal.isPayer[msg.sender], "Sender is invalid for the given proposalNumber");
        require(proposal.paidByAddress[msg.sender] == false, "Sender has already paid");
        require(
            msg.value == proposal.payerAmountsByAddress[msg.sender],
            "Invalid amount that is required for this address"
        );

        proposals[proposalNumber].paidByAddress[msg.sender] = true;
    }

    /**
     * @dev Payer withdraws the amount that they already paid for the SplitProposal. This method can
     * only be called before the SpitProposal is marked as completed. If payer is not a valid payer
     * or not already paid for the SplitProposal, the transaction is reverted.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function withdrawAmount(uint256 proposalNumber) public validProposalNumber(proposalNumber) {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.completed == false, "The proposal is already completed");
        require(proposal.isPayer[msg.sender], "Sender is invalid for the given proposalNumber");
        require(proposal.paidByAddress[msg.sender], "Sender has not paid yet");

        // https://docs.soliditylang.org/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
        proposals[proposalNumber].paidByAddress[msg.sender] = false;
        Address.sendValue(payable(msg.sender), proposal.payerAmountsByAddress[msg.sender]);
    }

    /**
     * @dev Receiver calls this method to mark the SplitProposal as completed. Once a SplitProposal
     * is marked as completed, sender is no longer able to withdraw amounts, and receiver can start
     * withdraw amounts.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function markAsCompleted(uint256 proposalNumber) public validProposalNumber(proposalNumber) {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(
            proposal.isReceiver[msg.sender],
            "msg.sender is not a valid receiver for the given proposal"
        );
        require(proposal.completed == false, "The proposal is already completed");
        for (uint256 i = 0; i < proposal.payers.length; i++) {
            require(
                proposal.paidByAddress[proposal.payers[i]],
                "Some payers have not made payment yet."
            );
        }

        proposal.completed = true;
    }

    /**
     * @dev Receiver calls this method to withdraw amount that is paid by payers. This method can
     * only be called after the SplitProposal is markAsCompleted.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function receiverWithdrawAmount(uint256 proposalNumber) public validProposalNumber(proposalNumber) {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(
            proposal.isReceiver[msg.sender],
            "msg.sender is not a valid receiver for the given proposal"
        );
        require(proposal.completed, "The proposal is not yet markAsCompleted");
        require(
            proposal.withdrawByAddress[msg.sender] == false,
            "msg.sender has withdraw the amounts"
        );

        // https://docs.soliditylang.org/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
        proposal.withdrawByAddress[msg.sender] = true;
        Address.sendValue(payable(msg.sender), proposal.receiverAmountsByAddress[msg.sender]);
    }

    /**
     * @dev Owner calls this method to withdraw tips given by the payers.
     */
    function withdrawTips() public onlyOwner {
        require(claimableTips != 0, "No tips for now");

        // https://docs.soliditylang.org/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
        uint256 toBeClaimedTips = claimableTips;
        claimableTips = 0;
        Address.sendValue(payable(msg.sender), toBeClaimedTips);
    }

    /**
     * @dev Whether the given proposalNumber contains a valid SplitProposal
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function isValidProposals(uint256 proposalNumber) public view returns (bool) {
        return validProposals[proposalNumber];
    }

    /**
     * @dev Whether the given proposalNumber contains a completed SplitProposal
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function isCompleted(
        uint256 proposalNumber
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (bool)
    {
        return proposals[proposalNumber].completed;
    }

    /**
     * @dev Returns a list of payers for the given proposalNumber.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function getPayers(
        uint256 proposalNumber
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (address[] memory)
    {
        return proposals[proposalNumber].payers;
    }

    /**
     * @dev Returns a list of amounts that are required to be paid by each payer for the given
     * proposalNumber.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function getAmounts(
        uint256 proposalNumber
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (uint256[] memory)
    {
        return proposals[proposalNumber].payerAmounts;
    }

    /**
     * @dev Returns the amount that is required to be paid by payer in a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param payer The payer address
     */
    function getAmountForPayer(
        uint256 proposalNumber,
        address payer
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (uint256)
    {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.isPayer[payer], "Invalid payer for the proposalNumber");
        return proposal.payerAmountsByAddress[payer];
    }

    /**
     * @dev Whether a given payer address is a valid payer in a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param payer The payer address
     */
    function isPayer(
        uint256 proposalNumber,
        address payer
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (bool)
    {
        return proposals[proposalNumber].isPayer[payer];
    }

    /**
     * @dev Whether a given payer address has paid for a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param payer The payer address
     */
    function isPaidForPayer(
        uint256 proposalNumber,
        address payer
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (bool)
    {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.isPayer[payer], "Invalid payer for the proposalNumber");
        return proposal.paidByAddress[payer];
    }
}