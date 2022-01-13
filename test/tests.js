const {expect} = require('chai')
const {BigNumber} = require('ethers')

describe('ETHPool', function () {
	let pool
	let owner, addr1, addr2, addr3, addr4, addr5, addrs

	beforeEach(async function () {
		const ETHPool = await ethers.getContractFactory('ETHPool')
		;[owner, addr1, addr2, addr3, addr4, addr5, ...addrs] =
			await ethers.getSigners()

		pool = await ETHPool.deploy()
		await pool.deployed()
	})

	describe('Team memeber role', async function () {
		it('Should return the owner as team member', async function () {
			expect(await pool.isTeamMember(owner.address)).to.equal(true)
			expect(await pool.amTeamMember()).to.equal(true)

			expect(await pool.connect(addr1).isTeamMember(owner.address)).to.equal(
				true
			)
		})

		it('Should add a team member', async function () {
			expect(await pool.isTeamMember(addr1.address)).to.equal(false)

			const addAdmin1 = await pool.addTeamMember(addr1.address)
			await addAdmin1.wait()

			expect(await pool.isTeamMember(addr1.address)).to.equal(true)
		})
	})

	describe('Initialization', async function () {
		it('Should start with 0 NFTs', async function () {
			expect(await pool.tokensAmount()).to.equal(0)
			expect(await pool.activeTokens()).to.equal(0)
			expect(await pool.exists(0)).to.equal(false)
			expect(await pool.exists(1)).to.equal(false)
		})
	})

	async function addLiquidity(_addr, _value) {
		const _addLiquidity = await pool
			.connect(_addr)
			.addLiquidity({value: _value})
		await _addLiquidity.wait()
		return _addLiquidity
	}

	describe('Adding liquidity', async function () {
		let deposit = ethers.utils.parseEther('1')

		beforeEach(async function () {
			await addLiquidity(addr1, deposit)
		})

		it('Should return first token', async function () {
			expect(await pool.exists(1)).to.equal(true)
			expect(await pool.tokensAmount()).to.equal(1)
			expect(await pool.activeTokens()).to.equal(1)
			expect(await pool.balanceOf(addr1.address)).to.equal(1)
		})

		it('Balance equal to deposit', async function () {
			expect(await pool.balanceOfToken(1)).to.equal(deposit)
			expect(await pool.deposits(1)).to.equal(deposit)
			expect(await pool.rewards(1)).to.equal(0)
		})
	})

	async function depositRewards(_value) {
		const _depositRewards = await pool.depositRewards({value: _value})
		await _depositRewards.wait()
		return _depositRewards
	}

	describe('Depositing rewards', async function () {
		let deposit = ethers.utils.parseEther('1')
		let rewards = ethers.utils.parseEther('0.5')

		it('Should revert if no deposits were made', async function () {
			await expect(pool.depositRewards({value: rewards})).to.be.revertedWith(
				'No deposits yet'
			)
		})

		describe('1 deposit, 1 reward', async function () {
			beforeEach(async function () {
				await addLiquidity(addr1, deposit)
				await depositRewards(rewards)
			})

			it('Should update last reward timestamp', async function () {
				expect(parseInt(await pool.lastRewardTimestamp())).to.be.greaterThan(0)
			})

			it('Should add rewards to token #1', async function () {
				expect(await pool.deposits(1)).to.equal(deposit)
				expect(await pool.rewards(1)).to.equal(rewards)
				expect(await pool.balanceOfToken(1)).to.equal(deposit.add(rewards))
			})
		})

		describe('2 deposits, 1 reward', async function () {
			let addLiquidity1
			let addLiquidity2
			let depositRewards1

			beforeEach(async function () {
				addLiquidity1 = await addLiquidity(addr1, deposit)
				addLiquidity2 = await addLiquidity(addr1, deposit)
				depositRewards1 = await depositRewards(rewards)
			})

			function points(liquidityDeposit, rewardsDeposit) {
				const delta = BigInt(
					rewardsDeposit.blockNumber - liquidityDeposit.blockNumber
				)
				const value = liquidityDeposit.value.toBigInt()
				return delta * value
			}

			function expectedRewards(liquidityDeposits, rewardsDeposit) {
				const _points = liquidityDeposits.map((d) => points(d, rewardsDeposit))
				const totalPoints = _points.reduce(function (a, b) {
					return a + b
				}, BigInt(0))
				return _points.map(
					(p) => (p * rewardsDeposit.value.toBigInt()) / totalPoints
				)
			}

			it("Should assign proportional rewards according to deposit's timestamp", async function () {
				const _expectedRewards = expectedRewards(
					[addLiquidity1, addLiquidity2],
					depositRewards1
				)
				const r1 = await pool.rewards(1)
				const r2 = await pool.rewards(2)
				expect(r1.toBigInt()).to.equal(_expectedRewards[0])
				expect(r2.toBigInt()).to.equal(_expectedRewards[1])
			})
		})
	})
})
