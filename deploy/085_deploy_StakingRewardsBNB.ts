import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, getOrNull, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  const staking = await getOrNull("StakingRewardsBNB")
  if (staking) {
    log(`reusing "StakingRewardsBNB" at ${staking.address}`)
  } else {
    await deploy("StakingRewardsBNB", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address,
        (await get("UP")).address,
        (await get("WBNB")).address,
        ZERO_ADDRESS,
        "500000000000000",
        0,
        "1000000000000000000"
      ]
    })
  }
}

export default func
func.tags = ["StakingRewardsBNB"]
func.dependencies = ["Core","UP","WBNB"]