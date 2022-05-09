import '@nomiclabs/hardhat-waffle';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';
import type {Split} from '../typechain-types/contracts';
import type {BigNumber, ContractTransaction} from 'ethers';

const NULL_ADDRESS = ethers.utils.getAddress(
  '0x0000000000000000000000000000000000000000'
);

async function createSplitContract(): Promise<Split> {
  const SplitContract = await ethers.getContractFactory('Split');
  const split = await SplitContract.deploy();
  await split.deployed();
  return split;
}

interface CreateSplitProposalResult {
  proposalNumber: BigNumber;
  amount: number;
}

async function createSplitProposal(
  split: Split,
  payers: string[],
  receiver: string
): Promise<CreateSplitProposalResult> {
  const amounts = [1];

  const results = await split.createSplitProposal(payers, amounts, receiver);
  expect(results.value).to.equal(0);
  return {
    proposalNumber: results.value,
    amount: amounts[0],
  };
}

describe('Split.createSplitProposal', () => {
  let split: Split;
  let payerSigner: SignerWithAddress;
  let receiverSigner: SignerWithAddress;

  beforeEach(async () => {
    split = await createSplitContract();
    let _owner: SignerWithAddress;
    [_owner, payerSigner, receiverSigner] = await ethers.getSigners();
  });

  it('Should deploy SplitProposal successfully', async () => {
    // No-op
  });

  it('Should createSplitProposal successfully', async () => {
    const amounts = [1];
    const results: ContractTransaction = await split.createSplitProposal(
      [payerSigner.address],
      amounts,
      receiverSigner.address
    );
    expect(results.value).to.equal(0);
  });

  it('Should not createSplitProposal if payers is empty', async () => {
    const amounts = [1];
    await expect(split.createSplitProposal([], amounts, receiverSigner.address))
      .to.be.reverted;
  });

  it('Should not createSplitProposal if receiver address is 0x0', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal([payerSigner.address], amounts, NULL_ADDRESS)
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if payer address is 0x0', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal([NULL_ADDRESS], amounts, receiverSigner.address)
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if payer addresses are duplicated', async () => {
    const amounts = [1, 2];
    await expect(
      split.createSplitProposal(
        [payerSigner.address, payerSigner.address],
        amounts,
        receiverSigner.address
      )
    ).to.be.reverted;
  });
});

describe('Split.sendAmount', () => {
  let split: Split;
  let payerSigner: SignerWithAddress;
  let receiverSigner: SignerWithAddress;

  beforeEach(async () => {
    split = await createSplitContract();
    let _owner: SignerWithAddress;
    [_owner, payerSigner, receiverSigner] = await ethers.getSigners();
  });

  it('Should sendAmount successfully by payer', async () => {
    const {proposalNumber, amount} = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );
    await expect(
      await split
        .connect(payerSigner)
        .sendAmount(proposalNumber, {value: amount})
    ).to.changeEtherBalances([payerSigner, receiverSigner, split], [-1, 0, 1]);

    expect(await split.isPaidForPayer(proposalNumber, payerSigner.address)).to
      .be.true;
  });

  it('Should not sendAmount with invalid proposalNumber', async () => {
    const result = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );
    await expect(
      split
        .connect(payerSigner)
        .sendAmount(ethers.BigNumber.from(1), {value: result.amount})
    ).to.be.reverted;
  });

  it('Should not sendAmount with completed proposal', async () => {
    const {proposalNumber, amount} = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );
    await expect(
      await split
        .connect(payerSigner)
        .sendAmount(proposalNumber, {value: amount})
    ).to.changeEtherBalances([payerSigner, receiverSigner, split], [-1, 0, 1]);
    await expect(
      await split.connect(receiverSigner).sendToReceiver(proposalNumber)
    ).to.changeEtherBalances([payerSigner, receiverSigner, split], [0, 1, -1]);

    await expect(
      split.connect(payerSigner).sendAmount(proposalNumber, {value: amount})
    ).to.be.reverted;
  });

  it('Should not sendAmount if sender is not a valid payer', async () => {
    const {proposalNumber, amount} = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );
    await expect(
      split.connect(receiverSigner).sendAmount(proposalNumber, {value: amount})
    ).to.be.reverted;
  });

  it('Should not sendAmount if sender has already paid', async () => {
    const {proposalNumber, amount} = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );
    await expect(
      await split
        .connect(payerSigner)
        .sendAmount(proposalNumber, {value: amount})
    ).to.changeEtherBalances([payerSigner, receiverSigner, split], [-1, 0, 1]);
    await expect(
      split.connect(payerSigner).sendAmount(proposalNumber, {value: amount})
    ).to.be.reverted;
  });

  it('Should not sendAmount if sender sends invalid amount', async () => {
    const result = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );
    await expect(
      split
        .connect(payerSigner)
        .sendAmount(result.proposalNumber, {value: ethers.BigNumber.from(123)})
    ).to.be.reverted;
  });
});

describe('Split.withdrawAmount', () => {
  let split: Split;
  let payerSigner: SignerWithAddress;
  let receiverSigner: SignerWithAddress;
  let result: CreateSplitProposalResult;

  beforeEach(async () => {
    split = await createSplitContract();
    let _owner: SignerWithAddress;
    [_owner, payerSigner, receiverSigner] = await ethers.getSigners();

    result = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );

    await expect(
      await split
        .connect(payerSigner)
        .sendAmount(result.proposalNumber, {value: result.amount})
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [-result.amount, 0, result.amount]
    );
    expect(
      await split.isPaidForPayer(result.proposalNumber, payerSigner.address)
    ).to.be.true;
  });

  it('Should withdrawAmount successfully by payer', async () => {
    await expect(
      await split.connect(payerSigner).withdrawAmount(result.proposalNumber)
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [result.amount, 0, -result.amount]
    );
    expect(
      await split.isPaidForPayer(result.proposalNumber, payerSigner.address)
    ).to.be.false;
  });

  it('Should not withdrawAmount if invalid proposalNumber', async () => {
    await expect(
      split.connect(payerSigner).withdrawAmount(ethers.BigNumber.from(123))
    ).to.be.reverted;
  });

  it('Should not withdrawAmount if proposal is completed', async () => {
    await expect(
      await split.connect(receiverSigner).sendToReceiver(result.proposalNumber)
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [0, result.amount, -result.amount]
    );

    await expect(
      split.connect(payerSigner).withdrawAmount(result.proposalNumber)
    ).to.be.reverted;
  });

  it('Should not withdrawAmount if not payer', async () => {
    await expect(
      split.connect(receiverSigner).withdrawAmount(result.proposalNumber)
    ).to.be.reverted;
  });

  it('Should not withdrawAmount if not yet paid', async () => {
    await expect(
      await split.connect(payerSigner).withdrawAmount(result.proposalNumber)
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [result.amount, 0, -result.amount]
    );
    await expect(
      split.connect(payerSigner).withdrawAmount(result.proposalNumber)
    ).to.be.reverted;
  });
});

describe('Split.sendToReceiver', () => {
  let split: Split;
  let payerSigner: SignerWithAddress;
  let receiverSigner: SignerWithAddress;
  let result: CreateSplitProposalResult;

  beforeEach(async () => {
    split = await createSplitContract();
    let _owner: SignerWithAddress;
    [_owner, payerSigner, receiverSigner] = await ethers.getSigners();

    result = await createSplitProposal(
      split,
      [payerSigner.address],
      receiverSigner.address
    );

    await expect(
      await split
        .connect(payerSigner)
        .sendAmount(result.proposalNumber, {value: result.amount})
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [-result.amount, 0, result.amount]
    );
    expect(
      await split.isPaidForPayer(result.proposalNumber, payerSigner.address)
    ).to.be.true;
  });

  it('Should sendToReceiver successfully', async () => {
    await expect(
      await split.connect(receiverSigner).sendToReceiver(result.proposalNumber)
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [0, result.amount, -result.amount]
    );

    await expect(
      await split.connect(receiverSigner).isCompleted(result.proposalNumber)
    ).to.be.true;
  });

  it('Should not sendToReceiver if not receiver', async () => {
    await expect(
      split.connect(payerSigner).sendToReceiver(result.proposalNumber)
    ).to.be.reverted;
  });

  it('Should not sendToReceiver if invalid proposalNumber', async () => {
    await expect(
      split.connect(receiverSigner).sendToReceiver(ethers.BigNumber.from(1))
    ).to.be.reverted;
  });

  it('Should not sendToReceiver if not yet paid', async () => {
    await expect(
      await split.connect(payerSigner).withdrawAmount(result.proposalNumber)
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [result.amount, 0, -result.amount]
    );
    expect(
      await split.isPaidForPayer(result.proposalNumber, payerSigner.address)
    ).to.be.false;

    await expect(
      split.connect(receiverSigner).sendToReceiver(result.proposalNumber)
    ).to.be.reverted;
  });
});
