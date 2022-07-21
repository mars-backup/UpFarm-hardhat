import _ from "lodash"
import BigNumber from "bignumber.js"
import { Signer } from "ethers"
import { solidity } from "ethereum-waffle"
import { ethers, deployments } from "hardhat"
import chai from "chai"
import {
  UpFarm,
  MarsSwapRouter,
  MarsSwapPair,
  GenericERC20,
  StrategyPCS,
  UpToken,
  VestingMaster,
  Core,
  CakeToken,
  WBNB,
  StrategyMars,
} from "../build/typechain"
import { mineBlocks } from "./testUtils"

chai.use(solidity)
const { expect } = chai
const { get } = deployments

const ONE = "1000000000000000000"

describe("UpFarm unit test", () => {
  let owner: Signer
  let user: Signer
  let timelock: Signer
  let attacker: Signer
  let core: Core
  let farm: UpFarm
  let up: UpToken
  let busd: GenericERC20
  let wbnb: WBNB
  let cake: CakeToken
  let btcb: GenericERC20
  let xms: GenericERC20
  let vesting: VestingMaster
  let want: MarsSwapPair
  let strategyPCS: StrategyPCS
  let ownerAddress: string
  let userAddress: string
  let timelockAddress: string

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture()

      const signers = await ethers.getSigners();
      [ owner, timelock, user, attacker ] = signers

      ownerAddress = await owner.getAddress()
      userAddress = await user.getAddress()
      timelockAddress = await timelock.getAddress()

      core = (await ethers.getContractAt(
        "Core",
        (
          await get("Core")
        ).address,
      )) as Core

      farm = (await ethers.getContractAt(
        "UpFarm",
        (
          await get("UpFarm")
        ).address,
      )) as UpFarm

      up = (await ethers.getContractAt(
        "UpToken",
        (
          await get("UP")
        ).address,
      )) as UpToken

      vesting = (await ethers.getContractAt(
        "VestingMaster",
        (
          await get("VestingMaster")
        ).address,
      )) as VestingMaster

      want = (await ethers.getContractAt(
        "MarsSwapPair",
        (
          await get("pcs_CAKE-BUSD")
        ).address,
      )) as MarsSwapPair

      busd = (await ethers.getContractAt(
        "GenericERC20",
        (
          await get("BUSD")
        ).address,
      )) as GenericERC20

      btcb = (await ethers.getContractAt(
        "GenericERC20",
        (
          await get("BTCB")
        ).address,
      )) as GenericERC20

      xms = (await ethers.getContractAt(
        "GenericERC20",
        (
          await get("XMS")
        ).address,
      )) as GenericERC20

      wbnb = (await ethers.getContractAt(
        "WBNB",
        (
          await get("WBNB")
        ).address,
      )) as WBNB

      cake = (await ethers.getContractAt(
        "CakeToken",
        (
          await get("CAKE")
        ).address,
      )) as CakeToken

      await up.transfer((await get("UpFarm")).address, "10000000000000000000000")
      await want.transfer(userAddress, ONE)

      await core.grantGovernor(timelockAddress)

      strategyPCS = (await ethers.getContractAt(
        "StrategyPCS",
        (
          await get("StrategyPCS_pcs_CAKE-BUSD_Earn_CAKE")
        ).address,
      )) as StrategyPCS

      const prouter = (await ethers.getContractAt(
        "MarsSwapRouter",
        (
          await get("PancakeSwapRouter")
        ).address,
      )) as MarsSwapRouter

      {
        const a0 = new BigNumber(1e18).times(6000).toString(10)
        const a1 = new BigNumber(1e19).toString(10)
        await busd.mint(ownerAddress, a0)
        await busd.approve(prouter.address, a0)
        await wbnb.approve(prouter.address, a1)
        await prouter.addLiquidity(
          busd.address,
          wbnb.address,
          a0,
          a1,
          0,
          0,
          ownerAddress,
          ONE
        )
      }

      // WBNB-BTCB
      {
        const a0 = new BigNumber(1e17).toString(10)
        const a1 = new BigNumber(1e19).toString(10)
        await btcb.approve(prouter.address, a0)
        await wbnb.approve(prouter.address, a1)
        await prouter.addLiquidity(
          btcb.address,
          wbnb.address,
          a0,
          a1,
          0,
          0,
          ownerAddress,
          ONE
        )
      }

      const mrouter = (await ethers.getContractAt(
        "MarsSwapRouter",
        (
          await get("MarsSwapRouter")
        ).address,
      )) as MarsSwapRouter

      // XMS-BTCB
      {
        const a0 = new BigNumber(1e23).toString(10)
        const a1 = new BigNumber(1e18).toString(10)
        await xms.approve(mrouter.address, a0)
        await btcb.approve(mrouter.address, a1)
        await mrouter.addLiquidity(
          xms.address,
          btcb.address,
          a0,
          a1,
          0,
          0,
          ownerAddress,
          ONE
        )
      }
      await btcb.transfer((await get("LiquidityMiningMasterBTCB")).address, new BigNumber(1e20).toString(10))

      // XMS-WBNB
      {
        const a0 = new BigNumber(1e22).toString(10)
        const a1 = new BigNumber(1e19).toString(10)
        await xms.approve(mrouter.address, a0)
        await wbnb.approve(mrouter.address, a1)
        await mrouter.addLiquidity(
          xms.address,
          wbnb.address,
          a0,
          a1,
          0,
          0,
          ownerAddress,
          ONE
        )
      }

      {
        const a0 = new BigNumber(1e22).toString(10)
        const a1 = new BigNumber(1e18).toString(10)
        await up.approve(mrouter.address, a0)
        await wbnb.approve(mrouter.address, a1)
        await mrouter.addLiquidity(
          up.address,
          wbnb.address,
          a0,
          a1,
          0,
          0,
          ownerAddress,
          ONE
        )
      }

      await owner.sendTransaction({
        to: (await get("LiquidityMiningMasterBNB")).address,
        value: ethers.utils.parseEther("10")
      })

      await farm.set(12, 1000, true, true)
      await farm.set(0, 1000, true, true)
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe('strategyPCS', () => {
    it('pcs_CAKE-BUSD', async () => {
      const pid = 12
      await want.connect(user).approve(farm.address, ONE)
      await expect(farm.connect(user).deposit(pid, ONE))
        .emit(farm, "Deposit")

      expect(await farm.stakedWantTokens(pid, userAddress)).to.equal("999999999999990000")
      await mineBlocks(10)
      expect(await farm.pendingToken(pid, userAddress)).to.equal("999999999999990000")
      await strategyPCS.connect(timelock).earn()
      const wantTokens = await farm.stakedWantTokens(pid, userAddress)
      await farm.connect(user).withdrawAll(pid)
    })
  })

  describe('strategyMars', () => {
    it('XMS earn WBNB', async () => {
      const pid = 0
      await xms.transfer(userAddress, ONE)
      const strat = (await ethers.getContractAt(
        "StrategyMars",
        (
          await get("StrategyMars_XMS_Earn_WBNB")
        ).address,
      )) as StrategyMars

      await xms.connect(user).approve(farm.address, ONE)
      await expect(farm.connect(user).deposit(pid, ONE))
        .emit(farm, "Deposit")

      expect(await farm.stakedWantTokens(pid, userAddress)).to.equal("999999999999990000")
      await mineBlocks(10)
      expect(await farm.pendingToken(pid, userAddress)).to.equal("999999999999990000")

      await strat.connect(timelock).earn()

      const wantTokens = await farm.stakedWantTokens(pid, userAddress)
      await farm.connect(user).withdrawAll(pid)
    })
  })
})