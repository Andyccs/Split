require("@nomiclabs/hardhat-waffle");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Split", function () {
  it("Should deploy SplitProposal successfully", async function () {
    const Split = await ethers.getContractFactory("Split");
    const split = await Split.deploy();
    await split.deployed();
  });

  it("Should createSplitProposal successfully", async function () {
    const Split = await ethers.getContractFactory("Split");
    const split = await Split.deploy();
    await split.deployed();

    const expectedSplitProposalNumber = ethers.BigNumber.from(0);

    const accounts = await hre.ethers.getSigners();
    const payers = [accounts[0].address];
    const amounts = [1];
    const receiver = accounts[1].address;

    const realSplitProposalNumber = await split.createSplitProposal(payers, amounts, receiver);
    expect(realSplitProposalNumber.value).to.equal(expectedSplitProposalNumber);
  });
});
