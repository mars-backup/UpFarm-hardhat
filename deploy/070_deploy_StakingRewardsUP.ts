import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, getOrNull, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  const staking = await getOrNull("StakingRewardsUP")
  if (staking) {
    log(`reusing "StakingRewardsUP" at ${staking.address}`)
  } else {
    await deploy("StakingRewardsUP", {
      from: deployer,
      contract: "StakingRewards",
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address,
        (await get("UP")).address,
        (await get("UP")).address,
        (await get("VestingMaster")).address,
        "500000000000000000",
        0,
        "1000000000000000000"
      ]
    })
  }
}

export default func
func.tags = ["StakingRewardsUP"]
func.dependencies = ["Core","VestingMaster","UP"]