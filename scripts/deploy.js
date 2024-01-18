// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const initialAmount = hre.ethers.utils.parseEther("0.03");
  const minimumAmount = hre.ethers.utils.parseEther("0.001");
  const subscriptionId = 123; // Replace with your actual subscription ID
  const consumerAddress = "0x1234567890123456789012345678901234567890"; // Replace with your actual consumer address

  const Games = await hre.ethers.getContractFactory("Games");
  const Gamesdeploy = await Games.deploy(
    minimumAmount,
    subscriptionId,
    consumerAddress,
    { value: initialAmount, gasLimit: 1000000 }
  );

  await Gamesdeploy.deployed();
  console.log(`https://sepolia.etherscan.io/address/${Gamesdeploy.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
