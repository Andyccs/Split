// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Split
 * @dev Split contract allows users to create SplitProposal. A SplitProposal contains payers, the
 * amounts that are required to be paid by each payer, receivers, and amounts that will be paid to
 * each receiver. Once all payers have paid the required amounts (by calling the sendAmount()
 * method), any receiver can initiate a markAsCompleted() call mark the SplitProposal as completed.
 * Once the SplitProposal is marked as completed, receiver can call receiverWithdrawAmount to
 * withdraw amount from the SplitProposal.
 *
 * Before a SplitProposal is marked as completed, any payer can call
 * withdrawAmount() to withdraw the amount that payer has already paid for the SplitProposal.
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract Split {

    string internal EC_50_INVALID_PROPOSAL_NUMBER = "50";

    // No payer address is provided
    string internal EC_51_NO_PAYER = "51";

    // No receiver address is provided
    string internal EC_52_NO_RECEIVER = "52";

    // The length of payers and payerAmounts must be the same
    string internal EC_53_INVALID_PAYERS_AND_AMOUNTS = "53";

    // The length of receivers and receiverAmounts must be the same
    string internal EC_54_INVALID_RECEIVERS_AND_AMOUNTS = "54";

    // Payer account is the zero address
    string internal EC_55_PAYER_ZERO_ADDRESS = "55";

    // A payer exist more than once in payers input argument
    string internal EC_56_PAYER_DUPLICATE = "56";

    // Receiver account is the zero address
    string internal EC_57_RECEIVER_ZERO_ADDRESS = "57";

    // A receiver exist more than once in receivers input argument
    string internal EC_58_RECEIVER_DUPLICATE = "58";

    // "sum(payerAmounts) != sum(receiverAmounts)"
    string internal EC_59_TOTAL_SUM_NOT_EQUAL = "59";

    // The proposal is already completed
    string internal EC_5A_PROPOSAL_COMPLETED = "5A";

    // The sender or receiver address is invalid
    string internal EC_5B_SENDER_RECEIVER_INVALID = "5B";

    // The sender/receiver address is already paid/withdraw
    string internal EC_5C_SENDER_RECEIVER_ALREDY_PAID_WITHDRAW = "5C";

    // Invalid amount sent by this address
    string internal EC_5D_INVALID_AMOUNT = "5D";

    // Sender/payer has not paid yet
    string internal EC_5E_SENDER_PAYER_NOT_YET_PAID = "5E";

    // msg.sender has withdraw the amounts
    string internal EC_5F_RECEIVER_ALREADY_WITHDRAW = "5F";

    // The proposal is not yet markAsCompleted
    string internal EC_60_PROPOSAL_NOT_COMPLETE = "60";

    // SplitProposal contains payers, the amounts that are required to be paid by each payer,
    // receivers, and amounts that will be paid to each receiver.
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

    // Whether the given proposalNumber is valid.
    modifier validProposalNumber(uint256 proposalNumber) {
        require(validProposals[proposalNumber], EC_50_INVALID_PROPOSAL_NUMBER);
        _;
    }

    constructor() { }

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
        require(payers.length != 0, EC_51_NO_PAYER);
        require(receivers.length != 0, EC_52_NO_RECEIVER);
        require(
            payers.length == payerAmounts.length,
            EC_53_INVALID_PAYERS_AND_AMOUNTS
        );
        require(
            receivers.length == receiverAmounts.length,
            EC_54_INVALID_RECEIVERS_AND_AMOUNTS
        );
        require(validProposals[nextProposalIndex] == false, "nextProposalIndex is already used");

        validProposals[nextProposalIndex] = true;
        SplitProposal storage proposal = proposals[nextProposalIndex];
        proposal.payers = payers;
        proposal.payerAmounts = payerAmounts;
        proposal.receivers = receivers;
        proposal.receiverAmounts = receiverAmounts;

        uint256 totalPayerAmounts;
        for (uint256 i = 0; i < payers.length; i++) {
            require(payers[i] != address(0), EC_55_PAYER_ZERO_ADDRESS);
            require(
                proposal.isPayer[payers[i]] == false,
                EC_56_PAYER_DUPLICATE
            );
            proposal.isPayer[payers[i]] = true;
            proposal.payerAmountsByAddress[payers[i]] = payerAmounts[i];
            totalPayerAmounts += payerAmounts[i];
        }

        uint256 totalReceiverAmounts;
        for (uint256 i = 0; i < receivers.length; i++) {
            require(receivers[i] != address(0), EC_57_RECEIVER_ZERO_ADDRESS);
            require(
                proposal.isReceiver[receivers[i]] == false,
                EC_58_RECEIVER_DUPLICATE
            );
            proposal.isReceiver[receivers[i]] = true;
            proposal.receiverAmountsByAddress[receivers[i]] = receiverAmounts[i];
            totalReceiverAmounts += receiverAmounts[i];
        }
        require(
            totalPayerAmounts == totalReceiverAmounts,
            EC_59_TOTAL_SUM_NOT_EQUAL
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
        require(proposal.completed == false, EC_5A_PROPOSAL_COMPLETED);
        require(proposal.isPayer[msg.sender], EC_5B_SENDER_RECEIVER_INVALID);
        require(
            proposal.paidByAddress[msg.sender] == false,
            EC_5C_SENDER_RECEIVER_ALREDY_PAID_WITHDRAW
        );
        require(
            msg.value == proposal.payerAmountsByAddress[msg.sender],
            EC_5D_INVALID_AMOUNT
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
        require(proposal.completed == false, EC_5A_PROPOSAL_COMPLETED);
        require(proposal.isPayer[msg.sender], EC_5B_SENDER_RECEIVER_INVALID);
        require(proposal.paidByAddress[msg.sender], EC_5E_SENDER_PAYER_NOT_YET_PAID);

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
            EC_5B_SENDER_RECEIVER_INVALID
        );
        require(proposal.completed == false, EC_5A_PROPOSAL_COMPLETED);
        for (uint256 i = 0; i < proposal.payers.length; i++) {
            require(
                proposal.paidByAddress[proposal.payers[i]],
                EC_5E_SENDER_PAYER_NOT_YET_PAID
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
            EC_5B_SENDER_RECEIVER_INVALID
        );
        require(proposal.completed, EC_60_PROPOSAL_NOT_COMPLETE);
        require(
            proposal.withdrawByAddress[msg.sender] == false,
            EC_5F_RECEIVER_ALREADY_WITHDRAW
        );

        // https://docs.soliditylang.org/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern
        proposal.withdrawByAddress[msg.sender] = true;
        Address.sendValue(payable(msg.sender), proposal.receiverAmountsByAddress[msg.sender]);
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
     * @dev Returns a list of receivers for the given proposalNumber.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function getReceivers(
        uint256 proposalNumber
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (address[] memory)
    {
        return proposals[proposalNumber].receivers;
    }

    // TODO: Rename getAmounts to getPayerAmounts
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
     * @dev Returns a list of amounts that will be paid by each receiver for the given
     * proposalNumber.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     */
    function getReceiverAmounts(
        uint256 proposalNumber
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (uint256[] memory)
    {
        return proposals[proposalNumber].receiverAmounts;
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
     * @dev Returns the amount that will be paid to receiver in a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param receiver The receiver address
     */
    function getAmountForReceiver(
        uint256 proposalNumber,
        address receiver
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (uint256)
    {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.isReceiver[receiver], "Invalid receiver for the proposalNumber");
        return proposal.receiverAmountsByAddress[receiver];
    }

    /**
     * @dev Whether a given address is a valid payer in a given SplitProposal.
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
     * @dev Whether a given address is a valid receiver in a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param receiver The receiver address
     */
    function isReceiver(
        uint256 proposalNumber,
        address receiver
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (bool)
    {
        return proposals[proposalNumber].isReceiver[receiver];
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

    /**
     * @dev Whether a given receiver address has withdrawn for a given SplitProposal.
     * @param proposalNumber The proposal number obtained by SplitProposal creator when creating a
     * new SplitProposal using createSplitProposal.
     * @param receiver The receiver address
     */
    function isWithdrawnForReceiver(
        uint256 proposalNumber,
        address receiver
    )
        public
        view
        validProposalNumber(proposalNumber)
        returns (bool)
    {
        SplitProposal storage proposal = proposals[proposalNumber];
        require(proposal.isReceiver[receiver], "Invalid receiver for the proposalNumber");
        return proposal.withdrawByAddress[receiver];
    }
}