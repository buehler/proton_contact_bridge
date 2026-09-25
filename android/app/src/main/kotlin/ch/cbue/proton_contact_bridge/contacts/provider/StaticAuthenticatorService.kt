package ch.cbue.proton_contact_bridge.contacts.provider

import android.app.Service
import android.content.Intent
import android.os.IBinder

class StaticAuthenticatorService : Service() {
    private lateinit var authenticator: StaticAuthenticator

    override fun onCreate() {
        super.onCreate()
        authenticator = StaticAuthenticator(this)
    }

    override fun onBind(intent: Intent): IBinder = authenticator.iBinder
}
