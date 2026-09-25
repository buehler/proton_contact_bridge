package ch.cbue.proton_contact_bridge.contacts.provider

import android.content.Context
import com.github.f4b6a3.ulid.Ulid
import androidx.core.content.edit

class ContactsSyncCursorState(context: Context) {
    private val preferences = context.getSharedPreferences("contacts_sync", Context.MODE_PRIVATE)

    val isInit
        get() = get() == INITIAL_CURSOR

    fun get(): Ulid =
        preferences.getString(KEY_CURSOR, INITIAL_CURSOR.toString()).let { s -> Ulid.from(s) }

    fun set(cursor: Ulid) {
        preferences.edit { putString(KEY_CURSOR, cursor.toString()) }
    }

    fun reset() {
        preferences.edit { remove(KEY_CURSOR) }
    }

    companion object {
        private val INITIAL_CURSOR = Ulid.MIN
        private const val KEY_CURSOR = "events_cursor"
    }
}