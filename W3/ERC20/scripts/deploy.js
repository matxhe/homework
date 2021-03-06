// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy

  // ERC20
  const GGToken = await hre.ethers.getContractFactory("GGToken");
  const totalToken = hre.ethers.utils.parseUnits("0",18);
  const ggToken = await GGToken.deploy(totalToken);

  await ggToken.deployed();

  console.log("GGToken deployed to:", ggToken.address);

  const VaultC = await hre.ethers.getContractFactory("Vault");
  const vault = await VaultC.deploy(ggToken.address);

  await vault.deployed();

  console.log("Vault deployed to:", vault.address);

  // ERC721
  const GGNFT = await hre.ethers.getContractFactory("GGNFT");
  const ggNFT = await GGNFT.deploy();

  await ggNFT.deployed();

  console.log("GG NFT deployed to:", ggNFT.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
