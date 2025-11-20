// Transactions removed: always return non-transactional result
async function startTransactionIfSupported() {
  return { session: null, transactional: false };
}

module.exports = { startTransactionIfSupported };
