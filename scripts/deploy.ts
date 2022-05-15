// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import {ethers} from 'hardhat';

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  const splitContract = await ethers.getContractFactory('Split');
  const deployedSplitContract = await splitContract.deploy();
  await deployedSplitContract.deployed();
  console.log('Split Contract Address:', deployedSplitContract.address);
}

main()
  .then(() => {})
  .catch(error => {
    console.error(error);
    throw new Error('Not able to deploy contract!');
  });
