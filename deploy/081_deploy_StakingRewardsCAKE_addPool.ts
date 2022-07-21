import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const POOLS = [
  {
    lp: 'UP',
    allocPoint: 0 // 1000
  }
]

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { getOrNull, get, save, execute } = deployments
  const { deployer } = await getNamedAccounts()

  for (let i = 0; i < POOLS.length; i++) {
    const { lp, allocPoint } = POOLS[i]
    const name = 'StakingRewardsCAKE-' + lp
    const pool = await getOrNull(name)
    if (pool) continue

    await execute(
      "StakingRewardsCAKE",
      { from: deployer, log: true },
      "addPool",
      allocPoint,
      (await get(lp)).address,
      false
    )

    await save(name , {
      abi: (await get("StakingRewardsCAKE")).abi,
      address: (await get("StakingRewardsCAKE")).address
    })
  }
}

export default func
func.tags = ["StakingRewardsCAKEAddPool"]
func.dependencies = ["StakingRewardsCAKE"]