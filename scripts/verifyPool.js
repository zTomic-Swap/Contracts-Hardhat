// scripts/verify-pool.js

// Import the HRE and the specific verifyContract function from the plugin
import hre from "hardhat";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
import constructorArgs from "../arguments.js"; // Uses ESM export from your arguments file

async function main() {
  const contractAddress = "0xCdfe3Ea6164F00F6E98dEd728333108b5Fd1b39A";

  console.log("Verifying contract at address:", contractAddress);
  console.log("Using constructor arguments:", JSON.stringify(constructorArgs, null, 2));

  try {
    // Use the programmatic verification function as per the new documentation
    await verifyContract(
      {
        address: contractAddress,
        constructorArgs: constructorArgs,
        provider: "etherscan", // Etherscan is used for the Sepolia network
      },
      hre // Pass the Hardhat Runtime Environment
    );

    console.log(`✅ Contract at ${contractAddress} verified successfully!`);

  } catch (error) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log("Contract is already verified on Etherscan.");
    } else {
      console.error("Verification failed with error:", error);
    }
  }
}

// Standard Hardhat script pattern
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

