import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const POOLS = [
  {
    lp: 'UP',
    allocPoint: 0 // 100
  }
]

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { getOrNull, get, save, execute } = deployments
  const { deployer } = await getNamedAccounts()

  for (let i = 0; i < POOLS.length; i++) {
    const { lp, allocPoint } = POOLS[i]
    const name = 'StakingRewardsUP-' + lp
    const pool = await getOrNull(name)
    if (pool) continue

    await execute(
      "StakingRewardsUP",
      { from: deployer, log: true },
      "addPool",
      allocPoint,
      (await get(lp)).address,
      true
    )

    await save(name , {
      abi: (await get("StakingRewardsUP")).abi,
      address: (await get("StakingRewardsUP")).address
    })
  }
}

export default func
func.tags = ["StakingRewardsUPAddPool"]
func.dependencies = ["StakingRewardsUP"]