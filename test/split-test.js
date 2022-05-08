require("@nomiclabs/hardhat-waffle");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const NULL_ADDRESS = ethers.utils.getAddress("0x0000000000000000000000000000000000000000");

async function createSplitContract() {
    const Split = await ethers.getContractFactory("Split");
    let split = await Split.deploy();
    await split.deployed();
    return split;
}

async function createSplitProposal(splitContract, payers, receiver) {
  const accounts = await ethers.getSigners();
  const amounts = [1];

  const results = await splitContract.createSplitProposal(payers, amounts, receiver);
  expect(results.value).to.equal(0);
  return {
    'proposalNumber': results.value,
    'amount': amounts[0]
  };
}

describe("Split.createSplitProposal", function () {
  it("Should deploy SplitProposal successfully", async function () {
    await createSplitContract();
  });

  it("Should createSplitProposal successfully", async function () {
    let split = await createSplitContract();

    const accounts = await ethers.getSigners();
    const payers = [accounts[0].address];
    const amounts = [1];
    const receiver = accounts[1].address;

    const results = await split.createSplitProposal(payers, amounts, receiver);
    expect(results.value).to.equal(0);
  });

  it("Should not createSplitProposal if payers is empty", async function () {
    let split = await createSplitContract();

    const accounts = await ethers.getSigners();
    const payers = [];
    const amounts = [1];
    const receiver = accounts[1].address;

    await expect(split.createSplitProposal(payers, amounts, receiver))
      .to.be.reverted;
  });

  it("Should not createSplitProposal if receiver address is 0x0", async function () {
    let split = await createSplitContract();

    const accounts = await ethers.getSigners();
    const payers = [accounts[0].address];
    const amounts = [1];
    const receiver = NULL_ADDRESS;

    await expect(split.createSplitProposal(payers, amounts, receiver))
      .to.be.reverted;
  });

  it("Should not createSplitProposal if payer address is 0x0", async function () {
    let split = await createSplitContract();

    const accounts = await ethers.getSigners();
    const payers = [NULL_ADDRESS];
    const amounts = [1];
    const receiver = accounts[1].address;

    await expect(split.createSplitProposal(payers, amounts, receiver))
      .to.be.reverted;
  });

  it("Should not createSplitProposal if payer addresses are duplicated", async function () {
    let split = await createSplitContract();

    const accounts = await ethers.getSigners();
    const payers = [accounts[0].address, accounts[0].address];
    const amounts = [1, 2];
    const receiver = accounts[1].address;

    await expect(split.createSplitProposal(payers, amounts, receiver))
      .to.be.reverted;
  });
});

describe("Split.sendAmount", () => {
  let split;

  let owner;
  let payerAddress;
  let receiverAddress;

  beforeEach(async () => {
    split = await createSplitContract();
    [owner, payerAddress, receiverAddress] = await ethers.getSigners();
  });

  it("Should sendAmount successfully by payer", async function () {
    const { proposalNumber, amount } =
        await createSplitProposal(split, [payerAddress.address], receiverAddress.address);
    await expect(await split.connect(payerAddress).sendAmount(proposalNumber, { value: amount }))
      .to.changeEtherBalances(
        [payerAddress, receiverAddress, split],
        [-1, 0, 1]
      );
  });

});
