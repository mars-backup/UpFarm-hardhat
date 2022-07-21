import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const master = await getOrNull("LiquidityMiningMasterCAKE")
  if (master) {
    log(`reusing "LiquidityMiningMasterCAKE" at ${master.address}`)
  } else {
    await deploy("LiquidityMiningMasterCAKE", {
      from: deployer,
      contract: "LiquidityMiningMaster",
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address,
        (await get("XMS")).address,
        ZERO_ADDRESS,
        (await get("CAKE")).address,
        "5000000000000000",
        0,
        "1000000000000000000"
      ]
    })
  }
}
export default func
func.tags = ["LiquidityMiningMasterCAKE"]
func.dependencies = ["Core","Tokens"]