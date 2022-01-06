const hre = require('hardhat')

async function main() {
	const Pool = await hre.ethers.getContractFactory('ETHPool')
	const pool = await Pool.deploy()

	await pool.deployed()
	;[owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()

	console.log('ETHPool deployed to:', pool.address)
	console.log('Deployed by:', owner.address)
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error)
		process.exit(1)
	})
