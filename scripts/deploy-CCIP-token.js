import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`[INFO] Deploying BurnMintERC20 with account: ${deployer.address}`);
  console.log(`[INFO] Account balance: ${(await ethers.provider.getBalance(deployer.address)).toString()}`);

  // Get parameters from environment variables
  const { NAME, SYMBOL, DECIMALS, MAX_SUPPLY, PRE_MINT, VERIFY_CONTRACT } = process.env;

  // --- Robust Validation for Environment Variables ---
  if (!NAME) {
    throw new Error("Missing environment variable: NAME (Token Name)");
  }
  if (!SYMBOL) {
    throw new Error("Missing environment variable: SYMBOL (Token Symbol)");
  }

  const parsedDecimals = parseInt(DECIMALS, 10);
  if (isNaN(parsedDecimals) || parsedDecimals < 0 || parsedDecimals > 255) {
    throw new Error(`Invalid or missing DECIMALS. Received: ${DECIMALS}`);
  }

  const parsedMaxSupply = MAX_SUPPLY ? ethers.parseUnits(MAX_SUPPLY, parsedDecimals) : null;
  if (MAX_SUPPLY && (parsedMaxSupply === null )) {
    throw new Error(`Invalid MAX_SUPPLY. Received: ${MAX_SUPPLY}`);
  }

  const parsedPreMint = PRE_MINT ? ethers.parseUnits(PRE_MINT, parsedDecimals) : null;
  if (PRE_MINT && (parsedPreMint === null )) {
    throw new Error(`Invalid PRE_MINT. Received: ${PRE_MINT}`);
  }
  
  // Log the extracted parameters for debugging
  console.log('[DEBUG] Extracted parameters for BurnMintERC20:', { 
    name: NAME, 
    symbol: SYMBOL, 
    decimals: parsedDecimals, 
    maxSupply: parsedMaxSupply ? parsedMaxSupply.toString() : 'N/A', 
    preMint: parsedPreMint ? parsedPreMint.toString() : 'N/A'
  });

  // --- Deploy Contract ---
  console.log('[INFO] Deploying BurnMintERC20 contract...');
  const ContractFactory = await ethers.getContractFactory('BurnMintERC20');
  
  // Assuming the BurnMintERC20 constructor takes (name, symbol, decimals, maxSupply, preMint)
  // Adjust these arguments based on your actual BurnMintERC20 constructor
  const token = await ContractFactory.deploy(
    NAME,
    SYMBOL,
    parsedDecimals,
    parsedMaxSupply || 0, // Pass 0 if MAX_SUPPLY is not provided
    parsedPreMint || 0   // Pass 0 if PRE_MINT is not provided
  );

  console.log('[INFO] Waiting for deployment to be confirmed...');
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();

  // THIS IS THE CRITICAL OUTPUT LINE THE SERVER PARSES
  console.log(`Token deployed to: ${tokenAddress}`);

  // --- Optional: Verification Step ---
  const network = await ethers.provider.getNetwork();
  const networkName = network.name;

  // It will only run if VERIFY_CONTRACT is "true" and it's not a local network.
  if (VERIFY_CONTRACT === "true" && networkName !== 'hardhat' && networkName !== 'localhost') {
    console.log(`[INFO] Starting contract verification on ${networkName} (may take a moment)...`);
    // Wait for 5 blocks to be mined for Etherscan to index the transaction
    await token.deploymentTransaction().wait(5); 

    try {
      // Access hre directly, as it's globally available
      await hre.run("verify:verify", {
        address: tokenAddress,
        // Ensure constructorArguments match the order and types of your contract's constructor
        constructorArguments: [NAME, SYMBOL, parsedDecimals, parsedMaxSupply || 0, parsedPreMint || 0], 
      });
      console.log("[SUCCESS] Contract verified successfully on Etherscan.");
    } catch (verifyError) {
      console.error("[ERROR] Contract verification failed:", verifyError.message);
    }
  }
}

// --- Main execution block ---
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FATAL] Token deployment script failed:', error);
    process.exit(1);
  });