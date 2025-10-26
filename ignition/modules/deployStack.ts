import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ZtomicModule from "./ztomic.js";
import ZtomicOptimizedModule from "./ztomicOptimized.js";

// Top-level composition module to deploy both Ztomic variants.
// Parameters are defined here so they can be passed via Ignition params.
export default buildModule("DeployZtomicStack", (m) => {
  // Declare parameters (shared across child modules)
  m.getParameter("depth", 20);
  m.getParameter<string>("stableOne");
  m.getParameter<string>("stableTwo");
  m.getParameter<string>("ccipRouter");
  m.getParameter<string>("linkToken");
  m.getParameter<bigint>("destinationChainSelector");

  const { ztomic } = m.useModule(ZtomicModule);
  const { ztomicOptimized } = m.useModule(ZtomicOptimizedModule);

  return { ztomic, ztomicOptimized };
});
