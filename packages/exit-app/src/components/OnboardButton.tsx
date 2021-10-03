import React, { useState } from 'react'
import Onboard from 'bnc-onboard'
import { ethers } from 'ethers'
import { Button } from '@material-ui/core'
import { useSafeAppsSDK } from '@gnosis.pm/safe-apps-react-sdk'

const ONBOARD_JS_DAPP_ID = process.env.REACT_APP_ONBOARD_JS_DAPP_ID

let provider: ethers.providers.Web3Provider

export const OnboardButton = (): JSX.Element => {
  const { safe } = useSafeAppsSDK()

  const [onboard] = useState(() => {
    return Onboard({
      dappId: ONBOARD_JS_DAPP_ID,
      networkId: safe.chainId,
      networkName: safe.chainId === 137 ? 'polygon' : undefined,
      subscriptions: {
        wallet: (wallet) => {
          console.log('before', { wallet, provider })
          if (wallet.provider) {
            provider = new ethers.providers.Web3Provider(wallet.provider)
          }
          console.log('after', { wallet, provider })
        },
      },
      walletCheck: [
        { checkName: 'derivationPath' },
        { checkName: 'accounts' },
        { checkName: 'connect' },
        { checkName: 'network' },
      ],
    })
  })

  const startOnboard = async () => {
    const selected = await onboard.walletSelect()
    if (selected) await onboard.walletCheck()
    console.log({ onboard, provider })
  }

  return <Button onClick={startOnboard}> Onboard</Button>
}
