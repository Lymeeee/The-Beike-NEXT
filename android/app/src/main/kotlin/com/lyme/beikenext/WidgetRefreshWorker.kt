package com.lyme.beikenext

import android.content.Context
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

class WidgetRefreshWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val WORK_NAME = "widget_refresh_periodic"

        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .build()

            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(
                15, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.LINEAR, 1, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }

    override fun doWork(): Result {
        return try {
            val context = applicationContext

            if (UpcomingClassWidget.isHolidayMode(context)) {
                return Result.success()
            }

            // Check if data is fresh enough
            val prefs = context.getSharedPreferences(
                "com.lyme.beikenext.widget",
                Context.MODE_PRIVATE
            )
            val json = prefs.getString("curriculum_full_data", null)

            if (json != null) {
                // Data exists — just refresh widget display
                UpcomingClassWidget.updateAllWidgets(context)
                UpcomingClassWidget.scheduleAutoRefresh(context)
            }

            Result.success()
        } catch (e: Exception) {
            Log.e("WidgetRefreshWorker", "Refresh failed", e)
            Result.retry()
        }
    }
}
