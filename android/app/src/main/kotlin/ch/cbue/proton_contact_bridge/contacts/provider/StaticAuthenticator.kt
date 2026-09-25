package ch.cbue.proton_contact_bridge.contacts.provider

import android.accounts.AbstractAccountAuthenticator
import android.accounts.Account
import android.accounts.AccountAuthenticatorResponse
import android.accounts.AccountManager
import android.content.ContentResolver
import android.content.Context
import android.os.Bundle
import android.provider.ContactsContract
import ch.cbue.proton_contact_bridge.R

class StaticAuthenticator(private val context: Context) : AbstractAccountAuthenticator(context) {
    companion object {
        const val ACCOUNT_NAME = "KinCrypt"
        const val ACCOUNT_TYPE = "ch.cbue.proton_contact_bridge.account"
    }

    override fun addAccount(
        response: AccountAuthenticatorResponse?,
        accountType: String?,
        authTokenType: String?,
        requiredFeatures: Array<out String?>?,
        options: Bundle?
    ): Bundle {
        if (accountType != ACCOUNT_TYPE) return Bundle().apply {
            putInt(AccountManager.KEY_ERROR_CODE, AccountManager.ERROR_CODE_BAD_ARGUMENTS)
            putString(AccountManager.KEY_ERROR_MESSAGE, "Unexpected account type")
        }

        val account = Account(ACCOUNT_NAME, ACCOUNT_TYPE)
        val manager = AccountManager.get(context)
        if (manager.getAccountsByType(ACCOUNT_TYPE).none { it.name == ACCOUNT_NAME } &&
            !manager.addAccountExplicitly(account, null, null)
        ) return Bundle().apply {
            putInt(AccountManager.KEY_ERROR_CODE, AccountManager.ERROR_CODE_REMOTE_EXCEPTION)
            putString(AccountManager.KEY_ERROR_MESSAGE, "Unable to create KinCrypt account")
        }

        if (ContentResolver.getIsSyncable(account, ContactsContract.AUTHORITY) <= 0) {
            ContentResolver.setIsSyncable(account, ContactsContract.AUTHORITY, 1)
        }
        return Bundle().apply {
            putString(AccountManager.KEY_ACCOUNT_NAME, account.name)
            putString(AccountManager.KEY_ACCOUNT_TYPE, account.type)
        }
    }

    override fun confirmCredentials(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        options: Bundle?
    ) = Bundle().apply {
        putBoolean("booleanResult", true)
    }

    override fun editProperties(
        response: AccountAuthenticatorResponse?,
        accountType: String?
    ) = Bundle()

    override fun getAuthToken(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        authTokenType: String?,
        options: Bundle?
    ) = Bundle().apply {
        putString("authAccount", account?.name)
        putString("accountType", account?.type)
        putString("authtoken", "local-database")
    }

    override fun getAuthTokenLabel(authTokenType: String?) = context.getString(R.string.app_name)

    override fun hasFeatures(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        features: Array<out String?>?
    ) = Bundle().apply {
        putBoolean("booleanResult", false)
    }

    override fun updateCredentials(
        response: AccountAuthenticatorResponse?,
        account: Account?,
        authTokenType: String?,
        options: Bundle?
    ) = Bundle()
}
