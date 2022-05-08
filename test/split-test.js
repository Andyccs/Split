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

describe("Split", function () {
  it("Should deploy SplitProposal successfully", async function () {
    await createSplitContract();
  });

  it("Should createSplitProposal successfully", async function () {
    let split = await createSplitContract();

    const expectedSplitProposalNumber = ethers.BigNumber.from(0);

    const accounts = await hre.ethers.getSigners();
    const payers = [accounts[0].address];
    const amounts = [1];
    const receiver = accounts[1].address;

    const results = await split.createSplitProposal(payers, amounts, receiver);
    expect(results.value).to.equal(expectedSplitProposalNumber);
  });

  it("Should not createSplitProposal if payers is empty", async function () {
    let split = await createSplitContract();

    const accounts = await hre.ethers.getSigners();
    const payers = [];
    const amounts = [1];
    const receiver = accounts[1].address;

    await expect(split.createSplitProposal(payers, amounts, receiver))
      .to.be.reverted;
  });

  it("Should not createSplitProposal if receiver address is 0x0", async function () {
    let split = await createSplitContract();

    const accounts = await hre.ethers.getSigners();
    const payers = [accounts[0].address];
    const amounts = [1];
    const receiver = NULL_ADDRESS;

    await expect(split.createSplitProposal(payers, amounts, receiver))
      .to.be.reverted;
  });

  it("Should not createSplitProposal if payer address is 0x0", async function () {
    let split = await createSplitContract();

    const accounts = await hre.ethers.getSigners();
    const payers = [NULL_ADDRESS];
    const amounts = [1];
    const receiver = accounts[1].address;

    await expect(split.createSplitProposal(payers, amounts, receiver))
      .to.be.reverted;
  });
});
