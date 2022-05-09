import "@nomiclabs/hardhat-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import type { Split } from "../typechain-types/contracts";
import type { ContractTransaction } from "ethers";

const NULL_ADDRESS = ethers.utils.getAddress("0x0000000000000000000000000000000000000000");

async function createSplitContract(): Promise<Split> {
    const SplitContract = await ethers.getContractFactory("Split");
    let split = await SplitContract.deploy();
    await split.deployed();
    return split;
}

async function createSplitProposal(
    split: Split,
    payers: string[],
    receiver: string) {
  const amounts = [1];

  const results = await split.createSplitProposal(payers, amounts, receiver);
  expect(results.value).to.equal(0);
  return {
    'proposalNumber': results.value,
    'amount': amounts[0]
  };
}

describe("Split.createSplitProposal", function () {
  let split: Split;

  let owner: SignerWithAddress;
  let payerSigner: SignerWithAddress;
  let receiverSigner: SignerWithAddress;

  beforeEach(async () => {
    split = await createSplitContract();
    [owner, payerSigner, receiverSigner] = await ethers.getSigners();
  });

  it("Should deploy SplitProposal successfully", async function () {
    // No-op
  });

  it("Should createSplitProposal successfully", async function () {
    const amounts = [1];
    const results: ContractTransaction =
        await split.createSplitProposal(
          [payerSigner.address],
          [1],
          receiverSigner.address);
    expect(results.value).to.equal(0);
  });


  it("Should not createSplitProposal if payers is empty", async function () {
    const amounts = [1];
    await expect(
        split.createSplitProposal(
          [],
          amounts,
          receiverSigner.address))
      .to.be.reverted;
  });

  it("Should not createSplitProposal if receiver address is 0x0", async function () {
    const amounts = [1];
    await expect(
        split.createSplitProposal(
          [payerSigner.address],
          amounts,
          NULL_ADDRESS)
        )
      .to.be.reverted;
  });

  it("Should not createSplitProposal if payer address is 0x0", async function () {
    const amounts = [1];
    await expect(
        split.createSplitProposal(
          [NULL_ADDRESS],
          amounts,
          receiverSigner.address)
        )
      .to.be.reverted;
  });

  it("Should not createSplitProposal if payer addresses are duplicated", async function () {
    const amounts = [1, 2];
    await expect(
        split.createSplitProposal(
          [payerSigner.address, payerSigner.address],
          amounts,
          receiverSigner.address)
        )
      .to.be.reverted;
  });
});

describe("Split.sendAmount", () => {
  let split: Split;

  let owner: SignerWithAddress;
  let payerAddress: SignerWithAddress;
  let receiverAddress: SignerWithAddress;

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

    expect(await split.isPaidForPayer(proposalNumber, payerAddress.address))
      .to.be.true;
    expect(await split.claimableTips()).to.equal(0);
  });

  it("Should not sendAmount with invalid proposalNumber", async function () {
    const { proposalNumber, amount } =
        await createSplitProposal(split, [payerAddress.address], receiverAddress.address);
    await expect(
        split
          .connect(payerAddress)
          .sendAmount(ethers.BigNumber.from(1), { value: amount }))
      .to.be.reverted;
  });

  it("Should not sendAmount with completed proposal", async function () {
    const { proposalNumber, amount } =
        await createSplitProposal(split, [payerAddress.address], receiverAddress.address);
    await expect(await split.connect(payerAddress).sendAmount(proposalNumber, { value: amount }))
      .to.changeEtherBalances(
        [payerAddress, receiverAddress, split],
        [-1, 0, 1]
      );
    await expect(await split.connect(receiverAddress).sendToReceiver(proposalNumber))
      .to.changeEtherBalances(
        [payerAddress, receiverAddress, split],
        [0, 1, -1]
      );

    await expect(split.connect(payerAddress).sendAmount(proposalNumber, { value: amount }))
      .to.be.reverted;
  });

  it("Should not sendAmount if sender is not a valid payer", async function () {
    const { proposalNumber, amount } =
        await createSplitProposal(split, [payerAddress.address], receiverAddress.address);
    await expect(split.connect(receiverAddress).sendAmount(proposalNumber, { value: amount }))
      .to.be.reverted
  });

  it("Should not sendAmount if sender has already paid", async function () {
    const { proposalNumber, amount } =
        await createSplitProposal(split, [payerAddress.address], receiverAddress.address);
    await expect(await split.connect(payerAddress).sendAmount(proposalNumber, { value: amount }))
      .to.changeEtherBalances(
        [payerAddress, receiverAddress, split],
        [-1, 0, 1]
      );
    await expect(split.connect(payerAddress).sendAmount(proposalNumber, { value: amount }))
      .to.be.reverted
  });

  it("Should not sendAmount if sender sends invalid amount", async function () {
    const { proposalNumber, amount } =
        await createSplitProposal(split, [payerAddress.address], receiverAddress.address);
    await expect(
        split
          .connect(payerAddress)
          .sendAmount(proposalNumber, { value: ethers.BigNumber.from(123) }))
      .to.be.reverted
  });

});