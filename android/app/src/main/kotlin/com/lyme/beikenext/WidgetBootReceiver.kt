package com.lyme.beikenext

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Reschedules widget auto-refresh alarms after device reboot.
 * The system kills all alarms on shutdown; this receiver restores them.
 */
class WidgetBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            UpcomingClassWidget.updateBackgroundRefresh(context)
        }
    }
}
