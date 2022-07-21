import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { keccak256 } from "@ethersproject/keccak256"

const MASTER_ROLE = keccak256(Buffer.from('MASTER_ROLE', 'utf-8'))

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { get, getOrNull, execute, save } = deployments
  const { deployer } = await getNamedAccounts()

  const name = "StakingRewardsUPGrant"
  const grant = await getOrNull(name)
  if (grant) return

  await execute(
    "Core",
    { from: deployer, log: true },
    "grantRole",
    MASTER_ROLE,
    (await get("StakingRewardsUP")).address
  )

  await save(name , {
    abi: (await get("StakingRewardsUP")).abi,
    address: (await get("StakingRewardsUP")).address
  })
}

export default func
func.tags = ["StakingRewardsUPGrant"]
func.dependencies = ["Core","StakingRewardsUP"]