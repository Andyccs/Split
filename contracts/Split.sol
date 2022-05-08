// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Split
 * @dev Split contract allows users to create SplitProposal. A SplitProposal contains an array of
 * payers, and the amounts that are required to be paid by each payer. Once all payers have paid the
 * required amounts (by calling the sendAmount() method), any payer or receiver can initiate a
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
        // indicated by the "amounts" variable below) before a SplitProposal can be marked as
        // completed. payers is one of the input arguments of createSplitProposal() method.
        address[] payers;

        // amounts is a list of amounts that need to be paid by each payer, i.e. payers[i] should
        // pay amounts[i] for all i < amounts.length, before a SplitProposal can be marked as
        // completed. amounts is one of the input arguments of createSplitProposal() method.
        uint256[] amounts;

        // receiver is the receiver address for all the amounts that are paid by payers. Note that
        // there is no restriction on who is the receiver, and it is possible for a receiver to be
        // one of the payer.
        address receiver;

        // isPayer is an index of whether a given payer address is a valid payer for a
        // SplitProposal. This index is created during createSplitProposal() and should never be
        // changed after that.
        mapping(address => bool) isPayer;

        // amountsByAddress is an index of payer address to the amount that is required to be paid
        // by the payer. This index is created during createSplitProposal() and should never be
        // changed after that.
        mapping(address => uint256) amountsByAddress;

        // totalAmount is the sum of "amounts". This value is created during createSplitProposal()
        // and should never be changed after that.
        uint256 totalAmount;

        // paidByAddress tracks whether a payer address has already made the required payment. The
        // value of this mapping is set to true when sendAmount() is called successfully. The value
        // of this mapping is set to false when withdrawAmount() is called successfully.
        mapping(address => bool) paidByAddress;

        // Whether this SplitProposal has completed. This field is set to true by sendToReceiver()
        // if the method completed successfully. Once a SplitProposal is completed, it is no longer
        // possible to interact with the SplitProposal.
        bool completed;
    }

    // All SplitProposals
    mapping (uint256 => SplitProposal) private proposals;

    // All valid SplitProposals
    mapping (uint256 => bool) private validProposals;

    // The next proposal index that is going to be used in createSplitProposal()
    uint256 nextProposalIndex;

    // Any tips that can be claimed by the owner. Extra amounts that are sent by payers using
    // sendAmount() to this contract are tracked by this variable, and these extra amounts are
    // considered tips for the owner.
    uint256 claimableTips;

    constructor() Ownable() {
    }

    // Function to receive Ether.
    receive() external payable {
        claimableTips += msg.value;
    }

    fallback() external payable {
        claimableTips += msg.value;
    }

    /**
     * @dev Creates a SplitProposal
     * @param payers An array of payers that need to pay the given amounts
     * @param amounts An array of amounts that needs to be paid by each payer
     * @return The SplitProposal number
     */
    function createSplitProposal(
        address[] memory payers,
        uint256[] memory amounts,
        address receiver
    )
        public
        returns (uint256)
    {
        require(payers.length != 0, "No payer address is provided");
        require(
            payers.length == amounts.length,
            "The length of payers and amounts must be the same"
        );
        require(receiver != address(0), "Receiver address should not be 0x0");
        require(validProposals[nextProposalIndex] == false, "nextProposalIndex is already used");

        validProposals[nextProposalIndex] = true;
        SplitProposal storage proposal = proposals[nextProposalIndex];
        proposal.payers = payers;
        proposal.amounts = amounts;
        proposal.receiver = receiver;

        for (uint256 i = 0; i < payers.length; i++) {
            require(payers[i] != address(0), "payer account is the zero address");
            require(
                proposal.isPayer[payers[i]] == false,
                "A payer exist more than once in payers input argument"
            );
            proposal.isPayer[payers[i]] = true;
            proposal.amountsByAddress[payers[i]] = amounts[i];
            proposal.totalAmount += amounts[i];
        }
        return nextProposalIndex++;
    }

    /**
     * @dev Payer sends the required amount to a specific SplitProposal (as indicated by
     * "proposalNumber" input argument). If payer is not a valid payer, not sending enough amount,
     * or already paid for the SplitProposal, the transaction is reverted. Any extra amount that are
     * sent by payer is not refundable, and are considered tips for the contract owner.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function sendAmount(uint256 proposalNumber) public payable {
        require(validProposals[proposalNumber], "Invalid proposalNumber");

        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.completed == false, "The proposal is already completed");
        require(proposal.isPayer[msg.sender], "Sender is invalid for the given proposalNumber");
        require(proposal.paidByAddress[msg.sender] == false, "Sender has already paid");
        require(
            msg.value >= proposal.amountsByAddress[msg.sender],
            "Invalid amount that is required for this address"
        );

        proposals[proposalNumber].paidByAddress[msg.sender] = true;
        claimableTips = msg.value - proposal.amountsByAddress[msg.sender];
    }

    /**
     * @dev Payer withdraws the amount that they already paid for the SplitProposal. This method can
     * only be called before the SpitProposal is marked as completed. If payer is not a valid payer
     * or not already paid for the SplitProposal, the transaction is reverted.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function withdrawAmount(uint256 proposalNumber) public payable {
        require(validProposals[proposalNumber], "Invalid proposalNumber in msg.data");

        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.completed == false, "The proposal is already completed");
        require(proposal.isPayer[msg.sender], "Sender is invalid for the given proposalNumber");
        require(proposal.paidByAddress[msg.sender], "Sender has not paid yet");

        // https://docs.soliditylang.org/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
        proposals[proposalNumber].paidByAddress[msg.sender] = false;
        Address.sendValue(payable(msg.sender), proposal.amountsByAddress[msg.sender]);
    }

    /**
     * @dev Payer or receiver call this method to send all the amounts that are already paid by
     * all the payers to the receiver. All payers must have made required payment, before this
     * method can be executed successfully.
     */
    function sendToReceiver(uint256 proposalNumber) public {
        require(validProposals[proposalNumber], "Invalid proposalNumber");

        SplitProposal storage proposal = proposals[proposalNumber];
        require(
            proposal.isPayer[msg.sender] || proposal.receiver == msg.sender,
            "msg.sender is not a valid payer or a receiver for the given proposal"
        );
        require(proposal.completed == false, "The proposal is already completed");
        for (uint256 i = 0; i < proposal.payers.length; i++) {
            require(
                proposal.paidByAddress[proposal.payers[i]],
                "Some payers have not made payment yet."
            );
        }

        // https://docs.soliditylang.org/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
        proposal.completed = true;
        Address.sendValue(payable(proposal.receiver), proposal.totalAmount);
    }

    /**
     * @dev Owner calls this method to withdraw tips given by the payers.
     */
    function withdrawTips() public onlyOwner {
        require(claimableTips != 0, "No tips for now");

        // https://docs.soliditylang.org/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
        claimableTips = 0;
        Address.sendValue(payable(msg.sender), claimableTips);
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
    function isCompleted(uint256 proposalNumber) public view returns (bool) {
        require(validProposals[proposalNumber], "Invalid proposalNumber");
        return proposals[proposalNumber].completed;
    }

    /**
     * @dev Returns a list of payers for the given proposalNumber.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function getPayers(uint256 proposalNumber) public view returns (address[] memory) {
        require(validProposals[proposalNumber], "Invalid proposalNumber");
        return proposals[proposalNumber].payers;
    }

    /**
     * @dev Returns a list of amounts that are required to be paid by each payer for the given
     * proposalNumber.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function getAmounts(uint256 proposalNumber) public view returns (uint256[] memory) {
        require(validProposals[proposalNumber], "Invalid proposalNumber");
        return proposals[proposalNumber].amounts;
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
        returns (uint256)
    {
        require(validProposals[proposalNumber], "Invalid proposalNumber");

        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.isPayer[payer], "Invalid payer for the proposalNumber");
        return proposal.amountsByAddress[payer];
    }

    /**
     * @dev Whether a given payer address is a valid payer in a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param payer The payer address
     */
    function isPayer(uint256 proposalNumber, address payer) public view returns (bool) {
        require(validProposals[proposalNumber], "Invalid proposalNumber");
        return proposals[proposalNumber].isPayer[payer];
    }

    /**
     * @dev Whether a given payer address has paid for a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param payer The payer address
     */
    function isPaidForPayer(uint256 proposalNumber, address payer) public view returns (bool) {
        require(validProposals[proposalNumber], "Invalid proposalNumber");

        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.isPayer[payer], "Invalid payer for the proposalNumber");
        return proposal.paidByAddress[payer];
    }
}