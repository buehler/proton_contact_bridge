package ch.cbue.proton_contact_bridge.contacts.provider

import android.app.Service
import android.content.AbstractThreadedSyncAdapter
import android.content.Intent
import android.os.IBinder
import android.util.Log

class StaticContactsSyncAdapterService : Service() {
    private lateinit var adapter: AbstractThreadedSyncAdapter

    override fun onCreate() {
        super.onCreate()
        adapter = StaticContactsSyncAdapter(this, true)
    }

    override fun onBind(intent: Intent): IBinder {
        return adapter.syncAdapterBinder
    }
}
