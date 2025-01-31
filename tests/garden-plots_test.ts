import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test rental extension and rewards system",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Initial plot rental
            Tx.contractCall('garden-plots', 'rent-plot', [
                types.uint(1)
            ], user1.address),
            
            // Check user stats after rental
            Tx.contractCall('garden-plots', 'get-user-stats', [
                types.principal(user1.address)
            ], user1.address),
            
            // Extend rental with loyalty discount
            Tx.contractCall('garden-plots', 'extend-rental', [
                types.uint(1)
            ], user1.address),
            
            // Claim rewards
            Tx.contractCall('garden-plots', 'claim-rewards', [],
                user1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        const userStats = block.receipts[1].result.expectOk();
        assertEquals(userStats.total_rentals, types.uint(1));
        block.receipts[2].result.expectOk();
        block.receipts[3].result.expectOk();
    },
});

Clarinet.test({
    name: "Test loyalty discount settings",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Set loyalty discount
            Tx.contractCall('garden-plots', 'set-loyalty-discount', [
                types.uint(20)
            ], deployer.address),
            
            // Non-owner attempt to set discount should fail
            Tx.contractCall('garden-plots', 'set-loyalty-discount', [
                types.uint(30)
            ], user1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(100)); // err-owner-only
    },
});
