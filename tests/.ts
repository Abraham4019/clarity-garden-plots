import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test plot rental lifecycle",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Set plot details
            Tx.contractCall('garden-plots', 'set-plot-details', [
                types.uint(1),
                types.uint(100),
                types.ascii("North Corner Plot")
            ], deployer.address),
            
            // Check if plot is available
            Tx.contractCall('garden-plots', 'is-plot-available', [
                types.uint(1)
            ], user1.address),
            
            // Rent the plot
            Tx.contractCall('garden-plots', 'rent-plot', [
                types.uint(1)
            ], user1.address),
            
            // Verify plot is no longer available
            Tx.contractCall('garden-plots', 'is-plot-available', [
                types.uint(1)
            ], user1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectBool(true);
        block.receipts[2].result.expectOk();
        block.receipts[3].result.expectOk().expectBool(false);
    },
});

Clarinet.test({
    name: "Test admin functions",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Set new rental price - should succeed for owner
            Tx.contractCall('garden-plots', 'set-rental-price', [
                types.uint(200)
            ], deployer.address),
            
            // Set new rental price - should fail for non-owner
            Tx.contractCall('garden-plots', 'set-rental-price', [
                types.uint(300)
            ], user1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(100)); // err-owner-only
    },
});
