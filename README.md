# MerkleVote
A small project to play with storing large chunks of data into a merkle root and executing on-chain logic using data from these merkle proofs. The contract creates a snapshot of token holder balances by constructing a merkle tree, saving only the root hash. Later when the token holders balance needs to be verified the contract can efficiently prove the balance and securely execute it's functionality, which in this case is a vote. This method can be used to create a balance snapshot for communities smaller than 2000 that have any current ERC20 token. This seems to be the current limitation of the merkle tree construction, although this contract could be greatly optimized.

# Benefits and Costs
Using a merkle construction allows for a cheaper overall gas costs for taking token snapshots. It has the benefit that you can import thousands of token holders at once, instead of amortizing the work to each individual token holder through a deposit/staking process. This process has limitations if the use case requires a stake to punish bad actors. It also isn't very useful as it doesn't guarantee that every token holder is included in the vote, although this could be added in for tokens that contain less than 1500 users, by verifying all users have been added by checking the tokens total supply.


# Gas Costs
Some initial tests show that gas costs for constructing a merkle tree & voting body:

* 1000 token holders: 4,958,146
* 500 token holders: 2,476,162
* 100 token holders: 638,009
* 10 token holders: 112,788



# Issues
There is a known bug in getSiblings() function within the test files. If you want to kill some bugs feel free to open a pull request.
