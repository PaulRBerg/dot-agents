# Browser Extension Error Patterns

Comprehensive patterns for identifying third-party browser extension errors in Sentry.

## Extension URL Patterns

### Chrome Extensions
```
chrome-extension://[extension-id]/
```

### Firefox Extensions
```
moz-extension://[uuid]/
```

### Safari Extensions
```
safari-extension://[bundle-id]-[hash]/
safari-web-extension://[uuid]/
```

### Edge Extensions
```
extension://[extension-id]/
```

## Common Injected Script Filenames

These filenames in stack traces indicate extension-injected code:

| Filename | Common Source |
|----------|---------------|
| `inpage.js` | Wallet extensions (MetaMask, etc.) |
| `content.js` | Generic content scripts |
| `contentscript.js` | Content scripts |
| `inject.js` | Script injection |
| `injected.js` | Script injection |
| `background.js` | Extension background scripts |
| `pageScript.js` | Page-level scripts |
| `provider.js` | Web3 providers |
| `ethereum.js` | Ethereum providers |

## Known Extension Error Messages

### Wallet Extensions

```
Cannot read properties of undefined (reading 'ethereum')
Cannot read properties of undefined (reading 'solana')
ethereum is not defined
window.ethereum is undefined
Failed to execute 'postMessage' on 'Window'
```

### General Extensions

```
ResizeObserver loop limit exceeded
ResizeObserver loop completed with undelivered notifications
Extension context invalidated
The message port closed before a response was received
A listener indicated an asynchronous response by returning true
Script error. (no stack trace)
```

### Ad Blockers

```
Failed to load resource: net::ERR_BLOCKED_BY_CLIENT
Blocked by content filter
The resource was blocked by a content blocker
```

### Password Managers

```
Cannot read properties of null (reading 'querySelector')
Unable to find form element
Password field not found
```

## Known Extension Stack Trace Patterns

### MetaMask
```
at MetaMask
at e.request (inpage.js:1:xxxxx)
at Object.request (provider.js:xxx)
```

### Coinbase Wallet
```
at CoinbaseWalletSDK
at CoinbaseWalletProvider
at coinbaseWalletExtension
```

### Phantom (Solana)
```
at PhantomInjectedProvider
at Proxy.request
solana is not defined
```

### WalletConnect
```
at WalletConnect
at Connector.connect
```

### Grammarly
```
at grammarly-desktop-integration
at GrammarlyButton
at grammarly-extension
```

### LastPass
```
at lastpass
at LPContentScriptFeatures
at lpOnLoad
```

### 1Password
```
at 1Password
at onepassword
at op-autofill
```

### Honey
```
at honey
at HoneyContainer
at PayPal Honey
```

### uBlock Origin / AdBlock
```
at uBlock
at AdBlock
at cosmetic-filter
```

## Detection Algorithm

To determine if an error is from a browser extension:

1. **Check error URL/filename:**
   ```javascript
   const isExtension = (url) => {
     return /^(chrome|moz|safari|safari-web)-extension:\/\//.test(url) ||
            /^extension:\/\//.test(url);
   };
   ```

2. **Check stack trace for extension patterns:**
   ```javascript
   const hasExtensionInStack = (stack) => {
     const extensionPatterns = [
       'chrome-extension://',
       'moz-extension://',
       'safari-extension://',
       'inpage.js',
       'content.js',
       'inject.js',
     ];
     return extensionPatterns.some(p => stack.includes(p));
   };
   ```

3. **Check for known extension error messages:**
   ```javascript
   const knownExtensionErrors = [
     'ResizeObserver loop',
     'Extension context invalidated',
     'ethereum is not defined',
     'Cannot read properties of undefined (reading \'ethereum\')',
   ];
   ```

## Stack Trace Examples

### Third Party (Extension)

```
TypeError: Cannot read properties of undefined (reading 'request')
    at e.request (chrome-extension://nkbihfbeogaeaoehlefnkodbefgpgknn/inpage.js:1:179839)
    at Object.request (chrome-extension://nkbihfbeogaeaoehlefnkodbefgpgknn/inpage.js:1:181024)
    at async handleConnect (webpack://portal/./src/hooks/useConnect.ts:45:12)
```

### Valid (Application)

```
TypeError: Cannot read properties of undefined (reading 'amount')
    at StreamCard (webpack://portal/./src/components/StreamCard.tsx:78:23)
    at renderWithHooks (webpack://portal/./node_modules/react-dom/...)
    at mountIndeterminateComponent (webpack://portal/./node_modules/react-dom/...)
```

## Sentry-Specific Detection

In Sentry event data, check these fields:

1. **`exception.values[].stacktrace.frames[].filename`** - Check for extension URLs
2. **`exception.values[].stacktrace.frames[].module`** - Check for extension modules
3. **`exception.values[].value`** - Check error message against known patterns
4. **`tags.browser.name`** - Some extension errors are browser-specific
5. **`contexts.browser`** - Browser context may reveal extension activity

## False Positive Considerations

Some errors that look like extension errors but might be valid:

- **Web3 errors without extension stack**: May be our code mishandling missing providers
- **ResizeObserver in our code**: Check if the observer is ours
- **Network errors**: Could be user connectivity OR our API issues

Always examine the full stack trace before categorizing.
