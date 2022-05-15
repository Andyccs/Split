# Split Contract

Split Contract is a smart contract written in Solidity to split all ETH paid by *m* number of payers to *n* number of receivers, e.g. Alice can pay 3 ETH to the smart contract and Bob can pay 2 ETH to the smart contract so that Charlie can receive 1 ETH from the smart contract and David can receive 4 ETH from the smart contract.

A Split Contract contains many Split Proposal. Anyone can interact with Split Contract to create new Split Proposal. A Split Proposal contains a list of payers of funds, a list of amounts that should be paid by each payer, a list of receivers of funds, and a list of amounts that should be withdrawable by receivers.

Here is an example of interaction with Split Contract:

1. Alice creates a Split Proposal by calling `Split.createSplitProposal`. When creating the Split Proposal, Alice specified that:
   - Alice should pay 3 ETH to the smart contract and Bob should pay 2 ETH to the smart contract
   - Charlie is entitled to 1 ETH from the smart contract and David is entitled to 4 ETH from the smart contract
2. Once Alice creates the Split Proposal, a Split `proposalNumber` is generated. Alice calls `Split.sendAmount(proposalNumber)` with 3 ETH to the smart contract.
3. Bob calls `Split.sendAmount(proposalNumber)` with 2 ETH to the smart contract.
4. Once all the payments have been made by payers, Charlie (a receiver) calls `Split.markAsCompleted(proposalNumber)` to mark the Split Proposal as completed.
5. After the Split Proposal is marked as completed, all receivers start calling `Split.receiverWithdrawAmount(proposalNumber)` to receive their funds, i.e. Charlie calls the method to get 1 ETH and David calls the method to get 4 ETH.

## Relationship to PaymentSplitter by OpenZepplin

This smart contract is very similar to [PaymentSplitter](https://docs.openzeppelin.com/contracts/2.x/api/payment#PaymentSplitter) contract by OpenZepplin. The PaymentSplitter by OpenZepplin has a predetermine list of receivers, with each receiver entitled to predetermine percentage of funds for each receiver. The contract allows anyone to send any amount of ETH to the smart contract. Once the contract is created, the list of receivers can't be changed (although it might be possible for one to subclass PaymentSplitter with public method to add receiver). Here is an example:

- When creating a new PaymentSplitter contract, Charlie and David are listed to be the receivers of funds, with Charlie getting 20% of the funds and David getting 80% of the funds.
- Alice sends 3 ETH to the smart contract and Bob sends 2 ETH to the smart contract
- Charlie calls `PaymentSplitter.release()` method to receive 1 ETH from the smart contract
- David calls `PaymentSplitter.release()` method to receive 4 ETH from the smart contract

There are many differences between the PaymentSplitter by OpenZepplin and Split Contract:

- PaymentSplitter contract can only have one Split Proposal. This means that everytime when a split/escrow account is required, a new PaymentSplitter contract needs to be deployed. In contrast, a Split Contract can contain multiple Split Proposal, so you don't need to deploy a new contract to facilitate a new payment that needs escrow account.
- PaymentSplitter contract does not have access control for payers, so anyone can make payment to the contract. In contrast, a Split Proposal in Split Contract contains a predetermine list of payers and only those payers can make payment to the Split Proposal.
- Once payers made payments to PaymentSplitter contract, it is not possible to withdraw the funds. In contrast, payers can withdraw funds that they paid to Split Contract as long as the Split Proposal is not yet marked as completed by receiver.

## Motivation for Split Contract

The idea of an [escrow](https://en.wikipedia.org/wiki/Escrow) account is important to facilitate various transactions, for example, in a real estate transaction, an escrow account is usually setup so that Buyer of a real estate deposits their down payment for the house to the escrow account, mortage lender deposits the rest of the required amounts to the escrow account, before the real estate transaction is considered completed and funds are disburse to the seller of the real estate, the seller's mortgage lender, buyer's real estate agent and seller's real estate agent.

In the real world, escrow account is usually set up by a third party, trusted entity. The goal of Split Contract is to be the escrow account **to facilitate payments involving multiple parties in web3**.

# Development

## Basic Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat coverage
npx hardhat node
node scripts/sample-script.js
npx hardhat help

npx gts lint
```
