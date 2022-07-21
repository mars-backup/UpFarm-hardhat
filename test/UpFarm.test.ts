import _ from "lodash"
import { Signer, BigNumber } from "ethers"
import { solidity } from "ethereum-waffle"
import { ethers, deployments } from "hardhat"
import chai from "chai"
import {
  UpFarm,
  MarsSwapRouter,
  MarsSwapFactory,
  MarsSwapPair,
  GenericERC20,
  MasterChef,
  StrategyPCS,
  UpToken,
  VestingMaster
} from "../build/typechain"
import { mineBlocks } from "./testUtils"

chai.use(solidity)
const { expect } = chai
const { get } = deployments

const DEAD_ADDRESS = "0x000000000000000000000000000000000000dead"

describe("UpFarm unit test", () => {
  let owner: Signer
  let alice: Signer
  let attacker: Signer
  let farm: UpFarm
  let up: UpToken
  let busd: GenericERC20
  let vesting: VestingMaster
  let want: MarsSwapPair
  let ownerAddress: string
  let aliceAddress: string
  let pid = 12

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture()

      const signers = await ethers.getSigners();
      [ owner, alice, attacker ] = signers

      ownerAddress = await owner.getAddress()
      aliceAddress = await alice.getAddress()

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

      const cake = (await ethers.getContractAt(
        "GenericERC20",
        (
          await get("CAKE")
        ).address,
      )) as GenericERC20

      const amt = BigNumber.from("10000000000000000000000")

      await up.transfer((await get("UpFarm")).address, "1000000000000000000000000")

      const router = await ethers.getContractAt(
        "MarsSwapRouter",
        (await get("PancakeSwapRouter")).address
      ) as MarsSwapRouter

      await cake.mint(ownerAddress, amt)
      await busd.approve(router.address, amt.mul(20))
      await cake.approve(router.address, amt)
      await router.addLiquidity(
        busd.address,
        cake.address,
        amt.mul(20),
        amt,
        0,
        0,
        ownerAddress,
        "1000000000000000000"
      )

      await farm.set(pid, 1000, true, true)
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe.skip('poolLength', () => {
    it('success', async () => {
      expect(await farm.poolLength()).to.equal(14)
    })
  })

  describe('add', () => {
    let lp: MarsSwapPair
    let strat: StrategyPCS
    beforeEach(async () => {
      const router = await ethers.getContractAt(
        "MarsSwapRouter",
        (await get("PancakeSwapRouter")).address
      ) as MarsSwapRouter
      const btcb = await ethers.getContractAt(
        "GenericERC20",
        (await get("BTCB")).address
      ) as GenericERC20
      const eth = await ethers.getContractAt(
        "GenericERC20",
        (await get("ETH")).address
      ) as GenericERC20
      await btcb.approve(router.address, 10000)
      await eth.approve(router.address, 10000)
      await router.addLiquidity(
        btcb.address,
        eth.address,
        10000,
        10000,
        0,
        0,
        ownerAddress,
        "1000000000000000000"
      )
      const factory = await ethers.getContractAt(
        "MarsSwapFactory",
        (await get("PancakeSwapFactory")).address
      ) as MarsSwapFactory
      lp = await ethers.getContractAt(
        "MarsSwapPair",
        (await factory.getPair(btcb.address, eth.address))
      ) as MarsSwapPair

      const chef = await ethers.getContractAt(
        "MasterChef",
        (await get("MasterChef")).address
      ) as MasterChef

      await chef.add(
        1000,
        lp.address,
        true
      )

      const pancakeRouter = (await get("PancakeSwapRouter")).address

      const StrategyPCS = await ethers.getContractFactory("StrategyPCS")
      strat = await StrategyPCS.deploy(
        [
          (await get("Core")).address,
          (await get("WBNB")).address,
          (await get("UpFarm")).address,
          (await get("UP")).address,
          lp.address,
          (await lp.token0()),
          (await lp.token1()),
          (await get("CAKE")).address,
          (await get("MasterChef")).address,
          ownerAddress,
          pancakeRouter,
          pancakeRouter,
          pancakeRouter,
          pancakeRouter,
          pancakeRouter,
          pancakeRouter,
          pancakeRouter
        ],
        5,
        false,
        true,
        false,
        [
          (await get("CAKE")).address,
          (await get("UP")).address,
        ],
        [],
        [
          (await get("CAKE")).address,
          (await lp.token0()),
        ],
        [],
        [
          (await get("CAKE")).address,
          (await lp.token1()),
        ],
        [],
        0,
        0,
        10000,
        10000
      ) as StrategyPCS
    })

    it('onlyGuardianOrGovernor', async () => {
      await expect(farm.connect(attacker).add(10, lp.address, true, strat.address, true))
        .to.be.revertedWith("CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor")
    })

    it('success', async () => {
      await farm.add(
        10,
        lp.address,
        true,
        strat.address,
        true
      )
    })
  })

  describe('set', () => {
    it('onlyGuardianOrGovernor', async () => {
      await expect(farm.connect(attacker).set(0, 20, true, true))
        .to.be.revertedWith("CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor")
    });

    it('success', async () => {
      await farm.set(0, 20, true, true)
      expect((await farm.poolInfo(0)).allocPoint).to.equal(20)
      expect(await farm.totalAllocPoint()).to.equal(1020)
    })
  })

  describe('pendingToken', () => {
    const amount = '1000000000000000000'
    it('success', async () => {
      await want.approve(farm.address, amount)
      await farm.deposit(pid, amount)
      await mineBlocks(10)
      expect(await farm.pendingToken(pid, ownerAddress)).to.equal('1999999999999980000')
    })
  })

  describe('stakedWantTokens', () => {
    const amount = '1000000'
    it('success', async () => {
      await want.approve(farm.address, amount);
      await farm.deposit(pid, amount);
      expect(await farm.stakedWantTokens(pid, ownerAddress)).to.equal('990000')
    })
  })

  describe('deposit', () => {
    const amount = '1000000'
    it('success', async () => {
      await want.approve(farm.address, amount)
      await farm.deposit(pid, amount)
      const u = await farm.userInfo(pid, ownerAddress)
      expect(u.shares).to.equal('990000')
    })
  })

  describe('withdraw', () => {
    const amount = '1000000'
    const half = '500000'

    beforeEach(async () => {
      await want.transfer(aliceAddress, amount)
    })

    it('withdraw amount success', async () => {
      await want.connect(alice).approve(farm.address, amount)
      await farm.connect(alice).deposit(pid, amount)
      await mineBlocks(10)
      await farm.connect(alice).withdraw(pid, amount)
      expect(await want.balanceOf(aliceAddress)).to.equal(989010)
      const u = await farm.userInfo(pid, aliceAddress)
      expect(u.shares).to.equal(0)
      expect(await up.balanceOf(aliceAddress)).to.equal("108900000000000000")
      const vestAmount = await vesting.connect(alice).getVestingAmount()
      expect(vestAmount[0]).to.equal('2069100000000000000')
    })

    it('withdraw half amount success', async () => {
      await want.connect(alice).approve(farm.address, amount)
      await farm.connect(alice).deposit(pid, amount)
      await mineBlocks(10)
      await farm.connect(alice).withdraw(pid, half)
      const afterwit = await want.balanceOf(aliceAddress)
      expect(afterwit.add(half)).to.equal(999500)
      const u = await farm.userInfo(pid, aliceAddress)
      expect(u.shares).to.equal(490000)
      expect(await up.balanceOf(aliceAddress)).to.equal("108900000000000000")
      const vestAmount = await vesting.connect(alice).getVestingAmount()
      expect(vestAmount[0]).to.equal('2069100000000000000')
    })
  })

  describe('withdrawAll', () => {
    const amount = '1000000'
    beforeEach(async () => {
      await want.transfer(aliceAddress, amount)
    })

    it('success', async () => {
      await want.connect(alice).approve(farm.address, amount)
      await farm.connect(alice).deposit(pid, amount)
      await mineBlocks(10)
      await farm.connect(alice).withdrawAll(pid)
      expect(await want.balanceOf(aliceAddress)).to.equal(989010)
      const u = await farm.userInfo(pid, aliceAddress)
      expect(u.shares).to.equal(0)
      expect(u.rewardDebt).to.equal(0)
      expect(await up.balanceOf(aliceAddress)).to.equal("108900000000000000")
      const vestAmount = await vesting.connect(alice).getVestingAmount()
      expect(vestAmount[0]).to.equal('2069100000000000000')
    })
  })

  describe.only('emergencyWithdraw', () => {
    const amount = '1000000'
    beforeEach(async () => {
      await want.transfer(aliceAddress, amount)
    })

    it('success', async () => {
      await want.connect(alice).approve(farm.address, amount)
      await farm.connect(alice).deposit(pid, amount)
      await mineBlocks(10)
      await farm.connect(alice).emergencyWithdraw(pid)
      expect(await want.balanceOf(aliceAddress)).to.equal(989010)
      const u = await farm.userInfo(pid, aliceAddress);
      expect(u.shares).to.equal(0)
      expect(u.rewardDebt).to.equal(0)
      expect(await up.balanceOf(aliceAddress)).to.equal(0)
      const vestAmount = await vesting.connect(alice).getVestingAmount()
      expect(vestAmount[0]).to.equal(0)
    })
  })

  describe('updateTokenPerBlock', () => {
    it('onlyGuardianOrGovernor', async () => {
      await expect(farm.connect(attacker).updateTokenPerBlock(0))
        .to.be.revertedWith("CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor")
    })

    it('success', async () => {
      await expect(farm.updateTokenPerBlock(0))
        .to.emit(farm, 'UpdateTokenPerBlock')
        .withArgs(ownerAddress, 0)
    })
  })

  describe( 'setVestingMaster', () => {
    it('onlyGovernor', async () => {
      await expect(farm.connect(attacker).setVestingMaster(ownerAddress))
        .to.be.revertedWith("CoreRef::onlyGovernor: Caller is not a governor")
    })

    it('success', async () => {
      await expect(farm.setVestingMaster(ownerAddress))
        .to.emit(farm, 'SetVestingMaster')
        .withArgs(ownerAddress, ownerAddress)
    })
  })

  describe('inCaseTokensGetStuck', () => {
    const amount = '1000000'
    it('onlyGovernor', async () => {
      await busd.transfer(farm.address, amount)
      await expect(farm.connect(attacker).inCaseTokensGetStuck(busd.address, amount))
        .to.be.revertedWith("CoreRef::onlyGovernor: Caller is not a governor")
    })

    it('success', async () => {
      const beforeAmount = await busd.balanceOf(ownerAddress)
      await busd.transfer(farm.address, amount)
      await expect(farm.inCaseTokensGetStuck(busd.address, amount))
      const afterAmount = await busd.balanceOf(ownerAddress)
      expect(beforeAmount).to.equal(afterAmount)
    })
  })
})