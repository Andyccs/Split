import '@nomiclabs/hardhat-waffle';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';
import type {Split} from '../typechain-types/contracts';
import type {BigNumber, ContractTransaction} from 'ethers';

const NULL_ADDRESS = ethers.utils.getAddress(
  '0x0000000000000000000000000000000000000000'
);

const INVALID_PROPOSAL_NUMBER = ethers.BigNumber.from(123);

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
  receivers: string[]
): Promise<CreateSplitProposalResult> {
  const amounts = [325];

  const results = await split.createSplitProposal(
    payers,
    amounts,
    receivers,
    amounts
  );
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
      [receiverSigner.address],
      amounts
    );
    expect(results.value).to.equal(0);
  });

  it('Should not createSplitProposal if payers is empty', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal([], amounts, [receiverSigner.address], amounts)
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if receivers is empty', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal([payerSigner.address], amounts, [], amounts)
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if payers.length != payerAmounts.length', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal(
        [payerSigner.address],
        [],
        [receiverSigner.address],
        amounts
      )
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if receivers.length != receiverAmounts.length', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal(
        [payerSigner.address],
        amounts,
        [receiverSigner.address],
        []
      )
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if payers.length != receivers.length', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal(
        [payerSigner.address, payerSigner.address],
        [1, 2],
        [receiverSigner.address],
        amounts
      )
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if receiver address is 0x0', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal(
        [payerSigner.address],
        amounts,
        [NULL_ADDRESS],
        amounts
      )
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if payer address is 0x0', async () => {
    const amounts = [1];
    await expect(
      split.createSplitProposal(
        [NULL_ADDRESS],
        amounts,
        [receiverSigner.address],
        amounts
      )
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if payer addresses are duplicated', async () => {
    await expect(
      split.createSplitProposal(
        [payerSigner.address, payerSigner.address],
        [1, 2],
        [receiverSigner.address],
        [1]
      )
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if receiver addresses are duplicated', async () => {
    await expect(
      split.createSplitProposal(
        [payerSigner.address],
        [1],
        [receiverSigner.address, receiverSigner.address],
        [1, 2]
      )
    ).to.be.reverted;
  });

  it('Should not createSplitProposal if sum(payerAmounts) != sum(receiverAmounts)', async () => {
    await expect(
      split.createSplitProposal(
        [payerSigner.address],
        [1],
        [receiverSigner.address],
        [2]
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
    const result = await createSplitProposal(
      split,
      [payerSigner.address],
      [receiverSigner.address]
    );
    expect(
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

  it('Should not sendAmount with invalid proposalNumber', async () => {
    const result = await createSplitProposal(
      split,
      [payerSigner.address],
      [receiverSigner.address]
    );
    await expect(
      split
        .connect(payerSigner)
        .sendAmount(ethers.BigNumber.from(1), {value: result.amount})
    ).to.be.reverted;
  });

  it('Should not sendAmount with completed proposal', async () => {
    const result = await createSplitProposal(
      split,
      [payerSigner.address],
      [receiverSigner.address]
    );
    expect(
      await split
        .connect(payerSigner)
        .sendAmount(result.proposalNumber, {value: result.amount})
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [-result.amount, 0, result.amount]
    );
    await split.connect(receiverSigner).markAsCompleted(result.proposalNumber);
    expect(
      await split.connect(receiverSigner).isCompleted(result.proposalNumber)
    ).to.be.true;
    expect(
      await split
        .connect(receiverSigner)
        .receiverWithdrawAmount(result.proposalNumber)
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [0, result.amount, -result.amount]
    );

    await expect(
      split
        .connect(payerSigner)
        .sendAmount(result.proposalNumber, {value: result.amount})
    ).to.be.reverted;
  });

  it('Should not sendAmount if sender is not a valid payer', async () => {
    const {proposalNumber, amount} = await createSplitProposal(
      split,
      [payerSigner.address],
      [receiverSigner.address]
    );
    await expect(
      split.connect(receiverSigner).sendAmount(proposalNumber, {value: amount})
    ).to.be.reverted;
  });

  it('Should not sendAmount if sender has already paid', async () => {
    const {proposalNumber, amount} = await createSplitProposal(
      split,
      [payerSigner.address],
      [receiverSigner.address]
    );
    expect(
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
      [receiverSigner.address]
    );
    await expect(
      split
        .connect(payerSigner)
        .sendAmount(result.proposalNumber, {value: INVALID_PROPOSAL_NUMBER})
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
      [receiverSigner.address]
    );

    expect(
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
    expect(
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
      split.connect(payerSigner).withdrawAmount(INVALID_PROPOSAL_NUMBER)
    ).to.be.reverted;
  });

  it('Should not withdrawAmount if proposal is completed', async () => {
    expect(
      await split.connect(receiverSigner).markAsCompleted(result.proposalNumber)
    ).to.changeEtherBalances([payerSigner, receiverSigner, split], [0, 0, 0]);

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
    expect(
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

describe('Split.markAsCompleted', () => {
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
      [receiverSigner.address]
    );

    expect(
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

  it('Should markAsCompleted successfully', async () => {
    expect(
      await split.connect(receiverSigner).markAsCompleted(result.proposalNumber)
    ).to.changeEtherBalances([payerSigner, receiverSigner, split], [0, 0, 0]);

    expect(
      await split.connect(receiverSigner).isCompleted(result.proposalNumber)
    ).to.be.true;
  });

  it('Should not markAsCompleted if not receiver', async () => {
    await expect(
      split.connect(payerSigner).markAsCompleted(result.proposalNumber)
    ).to.be.reverted;
  });

  it('Should not markAsCompleted if invalid proposalNumber', async () => {
    await expect(
      split.connect(receiverSigner).markAsCompleted(INVALID_PROPOSAL_NUMBER)
    ).to.be.reverted;
  });

  it('Should not markAsCompleted if not yet paid', async () => {
    expect(
      await split.connect(payerSigner).withdrawAmount(result.proposalNumber)
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [result.amount, 0, -result.amount]
    );
    expect(
      await split.isPaidForPayer(result.proposalNumber, payerSigner.address)
    ).to.be.false;

    await expect(
      split.connect(receiverSigner).markAsCompleted(result.proposalNumber)
    ).to.be.reverted;
  });
});

describe('Split.withdrawTips', () => {
  let split: Split;
  let ownerSigner: SignerWithAddress;
  let payerSigner: SignerWithAddress;
  let receiverSigner: SignerWithAddress;

  beforeEach(async () => {
    split = await createSplitContract();
    [ownerSigner, payerSigner, receiverSigner] = await ethers.getSigners();
  });

  it('Should withdrawTips successfully', async () => {
    const tipsAmount = ethers.BigNumber.from(999);
    expect(
      await payerSigner.sendTransaction({
        to: split.address,
        value: tipsAmount,
      })
    ).to.changeEtherBalances(
      [ownerSigner, payerSigner, receiverSigner, split],
      [0, -tipsAmount, 0, tipsAmount]
    );

    expect(await split.connect(ownerSigner).claimableTips()).to.equal(
      tipsAmount
    );

    expect(
      await split.connect(ownerSigner).withdrawTips()
    ).to.changeEtherBalances(
      [ownerSigner, payerSigner, receiverSigner, split],
      [tipsAmount, 0, 0, -tipsAmount]
    );

    expect(await split.connect(ownerSigner).claimableTips()).to.equal(0);
  });

  it('Should not withdrawTips if not owner', async () => {
    const tipsAmount = INVALID_PROPOSAL_NUMBER;
    expect(
      await payerSigner.sendTransaction({
        to: split.address,
        value: tipsAmount,
      })
    ).to.changeEtherBalances(
      [ownerSigner, payerSigner, receiverSigner, split],
      [0, -tipsAmount, 0, tipsAmount]
    );

    expect(await split.connect(ownerSigner).claimableTips()).to.equal(
      tipsAmount
    );

    await expect(split.connect(payerSigner).withdrawTips()).to.be.reverted;
  });

  it('Should not withdrawTips if no tips', async () => {
    await expect(split.connect(ownerSigner).withdrawTips()).to.be.reverted;
  });
});

describe('Split Getters', () => {
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
      [receiverSigner.address]
    );
  });

  it('Should getPayers successfully', async () => {
    expect(await split.getPayers(result.proposalNumber)).to.be.eql([
      payerSigner.address,
    ]);
  });

  it('Should not getPayers if invalid proposalNumber', async () => {
    await expect(split.getPayers(INVALID_PROPOSAL_NUMBER)).to.be.reverted;
  });

  it('Should getAmounts successfully', async () => {
    expect(await split.getAmounts(result.proposalNumber)).to.be.eql([
      ethers.BigNumber.from(result.amount),
    ]);
  });

  it('Should not getAmounts if invalid proposalNumber', async () => {
    expect(split.getAmounts(INVALID_PROPOSAL_NUMBER)).to.be.reverted;
  });

  it('Should getAmountForPayer successfully', async () => {
    expect(
      await split.getAmountForPayer(result.proposalNumber, payerSigner.address)
    ).to.be.equal(result.amount);
  });

  it('Should not getAmountForPayer if invalid proposalNumber', async () => {
    await expect(
      split.getAmountForPayer(INVALID_PROPOSAL_NUMBER, payerSigner.address)
    ).to.be.reverted;
  });

  it('Should not getAmountForPayer if invalid payer', async () => {
    await expect(
      split.getAmountForPayer(result.proposalNumber, receiverSigner.address)
    ).to.be.reverted;
  });

  it('Should return true for isPayer', async () => {
    expect(await split.isPayer(result.proposalNumber, payerSigner.address)).to
      .be.true;
  });

  it('Should return false if address is not payer', async () => {
    expect(await split.isPayer(result.proposalNumber, receiverSigner.address))
      .to.be.false;
  });

  it('Should throw for isPayer if invalid proposalNumber', async () => {
    await expect(split.isPayer(INVALID_PROPOSAL_NUMBER, payerSigner.address)).to
      .be.reverted;
  });
});

describe('Split.isPaidForPayer', () => {
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
      [receiverSigner.address]
    );
    expect(
      await split
        .connect(payerSigner)
        .sendAmount(result.proposalNumber, {value: result.amount})
    ).to.changeEtherBalances(
      [payerSigner, receiverSigner, split],
      [-result.amount, 0, result.amount]
    );
  });

  it('Should return true for isPaidForPayer', async () => {
    expect(
      await split.isPaidForPayer(result.proposalNumber, payerSigner.address)
    ).to.be.true;
  });

  it('Should throw for isPaidForPayer if address is not payer', async () => {
    await expect(
      split.isPaidForPayer(result.proposalNumber, receiverSigner.address)
    ).to.be.reverted;
  });

  it('Should throw for isPaidForPayer if invalid proposalNumber', async () => {
    await expect(
      split.isPaidForPayer(INVALID_PROPOSAL_NUMBER, payerSigner.address)
    ).to.be.reverted;
  });
});
