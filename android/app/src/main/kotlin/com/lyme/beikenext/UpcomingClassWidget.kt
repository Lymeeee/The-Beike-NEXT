package com.lyme.beikenext

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class UpcomingClassWidget : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "com.lyme.beikenext.widget"
        private const val KEY_LEGACY = "upcoming_class_data"
        private const val KEY_FULL_DATA = "curriculum_full_data"
        private const val REFRESH_INTERVAL_MS = 5 * 60 * 1000L
        private const val ACTION_AUTO_REFRESH = "com.lyme.beikenext.AUTO_REFRESH"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = buildRemoteViews(context)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, UpcomingClassWidget::class.java)
            )
            for (widgetId in widgetIds) {
                updateWidget(context, appWidgetManager, widgetId)
            }
        }

        fun saveFullData(context: Context, json: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_FULL_DATA, json)
                .apply()
        }

        fun isHolidayMode(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_FULL_DATA, null) ?: return false
            return try {
                JSONObject(json).optBoolean("holidayMode", false)
            } catch (e: Exception) {
                false
            }
        }

        fun updateBackgroundRefresh(context: Context) {
            if (isHolidayMode(context)) {
                cancelAutoRefresh(context)
                WidgetRefreshWorker.cancel(context)
            } else {
                scheduleAutoRefresh(context)
                scheduleWorkManagerRefresh(context)
            }
        }

        fun scheduleAutoRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, UpcomingClassWidget::class.java).apply {
                action = ACTION_AUTO_REFRESH
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

            val triggerAt = SystemClock.elapsedRealtime() + REFRESH_INTERVAL_MS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+: use setExactAndAllowWhileIdle for reliable doze-mode delivery
                // Requires SCHEDULE_EXACT_ALARM permission (granted by system for alarm clock apps)
                try {
                    val info = AlarmManager.AlarmClockInfo(triggerAt, pendingIntent)
                    alarmManager.setAlarmClock(info, pendingIntent)
                } catch (e: SecurityException) {
                    // Fallback: use exact alarm without clock priority
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent
                    )
                }
            } else {
                // Pre-Android 12: use setAlarmClock for best reliability
                val info = AlarmManager.AlarmClockInfo(triggerAt, pendingIntent)
                alarmManager.setAlarmClock(info, pendingIntent)
            }
        }

        fun cancelAutoRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, UpcomingClassWidget::class.java).apply {
                action = ACTION_AUTO_REFRESH
            }
            val flags = PendingIntent.FLAG_NO_CREATE or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }

        fun scheduleWorkManagerRefresh(context: Context) {
            WidgetRefreshWorker.schedule(context)
        }

        private fun getWeekIndexForDate(
            calendarDays: JSONArray?,
            termSeason: Int,
            maxWeekIndex: Int,
            todayYear: Int,
            todayMonth: Int,
            todayDay: Int
        ): Int? {
            // 1. Exact match
            if (calendarDays != null) {
                for (i in 0 until calendarDays.length()) {
                    val cd = calendarDays.getJSONObject(i)
                    if (cd.optInt("year") == todayYear &&
                        cd.optInt("month") == todayMonth &&
                        cd.optInt("day") == todayDay
                    ) {
                        return cd.getInt("weekIndex")
                    }
                }
            }

            // 2. Extrapolate from nearest calendar day
            if (calendarDays == null || calendarDays.length() == 0) return null

            val today = Calendar.getInstance().apply {
                set(todayYear, todayMonth - 1, todayDay)
            }

            var baseWeek = 0
            var minDiff = Int.MAX_VALUE
            val baseCal = Calendar.getInstance()

            for (i in 0 until calendarDays.length()) {
                val cd = calendarDays.getJSONObject(i)
                val cdCal = Calendar.getInstance().apply {
                    set(cd.optInt("year"), cd.optInt("month") - 1, cd.optInt("day"))
                }
                val diff = Math.abs((today.timeInMillis - cdCal.timeInMillis) / (24 * 60 * 60 * 1000))
                if (diff < minDiff) {
                    minDiff = diff.toInt()
                    baseWeek = cd.getInt("weekIndex")
                    baseCal.timeInMillis = cdCal.timeInMillis
                }
            }

            if (baseWeek == 0) return null

            val daysDiff = ((today.timeInMillis - baseCal.timeInMillis) / (24 * 60 * 60 * 1000)).toInt()
            val weeksDiff = Math.round(daysDiff / 7.0).toInt()
            return (baseWeek + weeksDiff).coerceIn(1, maxWeekIndex)
        }

        private fun getMaxWeekIndex(allClasses: JSONArray, calendarDays: JSONArray?): Int {
            var maxFromClasses = 0
            for (i in 0 until allClasses.length()) {
                val weeks = allClasses.getJSONObject(i).optJSONArray("weeks") ?: continue
                for (j in 0 until weeks.length()) {
                    val w = weeks.optInt(j)
                    if (w > maxFromClasses) maxFromClasses = w
                }
            }
            var maxFromCalendar = 0
            if (calendarDays != null) {
                for (i in 0 until calendarDays.length()) {
                    val w = calendarDays.getJSONObject(i).optInt("weekIndex")
                    if (w > maxFromCalendar) maxFromCalendar = w
                }
            }
            return maxOf(maxFromClasses, maxFromCalendar, 1)
        }

        private fun formatTime(minuteOfDay: Int): String {
            val h = minuteOfDay / 60
            val m = minuteOfDay % 60
            return "${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}"
        }

        private fun convertToMondayBased(javaDayOfWeek: Int): Int {
            return if (javaDayOfWeek == Calendar.SUNDAY) 7 else javaDayOfWeek - 1
        }

        private fun computeSummerWeekIndex(startYear: Int, startMonth: Int, startDay: Int): Int {
            val start = Calendar.getInstance().apply {
                set(startYear, startMonth - 1, startDay, 0, 0, 0)
            }
            val now = Calendar.getInstance()
            val diffDays = ((now.timeInMillis - start.timeInMillis) / (24 * 60 * 60 * 1000)).toInt()
            if (diffDays < 0) return 1
            return (diffDays / 7) + 1
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming_class)
            fillContent(context, views)
            return views
        }

        private fun fillContent(context: Context, views: RemoteViews) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_FULL_DATA, null)

            if (json == null) {
                hideAllFields(views)
                views.setTextViewText(R.id.class_name_text, "等待数据同步…")
                attachClickIntent(context, views)
                return
            }

            try {
                val data = JSONObject(json)
                if (!data.optBoolean("hasData", false)) {
                    hideAllFields(views)
                    views.setTextViewText(R.id.class_name_text, "课表未加载")
                    attachClickIntent(context, views)
                    return
                }

                if (data.optBoolean("holidayMode", false)) {
                    hideAllFields(views)
                    views.setTextViewText(R.id.class_name_text, "假期愉快，要天天开心呀～")
                    attachClickIntent(context, views)
                    return
                }

                if (data.optBoolean("examMode", false)) {
                    renderExamInfo(data, views)
                    attachClickIntent(context, views)
                    return
                }

                val calendar = Calendar.getInstance()
                val todayYear = calendar.get(Calendar.YEAR)
                val todayMonth = calendar.get(Calendar.MONTH) + 1
                val todayDay = calendar.get(Calendar.DAY_OF_MONTH)
                val todayWeekday = convertToMondayBased(calendar.get(Calendar.DAY_OF_WEEK))
                val termSeason = data.optInt("termSeason", 1)
                val isSummerTerm = termSeason >= 3
                val summerStartYear = data.optInt("summerTermStartYear", -1)
                val summerStartMonth = data.optInt("summerTermStartMonth", -1)
                val summerStartDay = data.optInt("summerTermStartDay", -1)

                // Summer term without start date configured
                if (isSummerTerm && (summerStartYear < 0 || summerStartMonth < 0 || summerStartDay < 0)) {
                    hideAllFields(views)
                    views.setTextViewText(R.id.class_name_text, "未设定小学期起始日")
                    attachClickIntent(context, views)
                    return
                }

                val allClasses = data.optJSONArray("allClasses") ?: run {
                    hideAllFields(views); views.setTextViewText(R.id.class_name_text, "课表数据异常"); return
                }
                val allPeriods = data.optJSONArray("allPeriods") ?: run {
                    hideAllFields(views); views.setTextViewText(R.id.class_name_text, "课表数据异常"); return
                }
                val calendarDays = data.optJSONArray("calendarDays")
                val maxWeek = getMaxWeekIndex(allClasses, calendarDays)

                // Find or extrapolate today's week index
                val todayWeekIndex: Int? = if (isSummerTerm && summerStartYear >= 0) {
                    computeSummerWeekIndex(summerStartYear, summerStartMonth, summerStartDay)
                } else {
                    getWeekIndexForDate(
                        calendarDays, termSeason, maxWeek,
                        todayYear, todayMonth, todayDay
                    )
                }

                if (todayWeekIndex == null) {
                    hideAllFields(views)
                    views.setTextViewText(R.id.class_name_text, "课表数据未就绪")
                    attachClickIntent(context, views)
                    return
                }

                // Use real weekday, no longer force Monday for summer term
                val lookupWeekday = todayWeekday

                // Filter today's classes
                val todayClasses = mutableListOf<JSONObject>()
                for (i in 0 until allClasses.length()) {
                    val cls = allClasses.getJSONObject(i)
                    if (cls.optInt("day") != lookupWeekday) continue
                    val weeks = cls.optJSONArray("weeks") ?: continue
                    for (j in 0 until weeks.length()) {
                        if (weeks.optInt(j) == todayWeekIndex) {
                            todayClasses.add(cls)
                            break
                        }
                    }
                }

                if (todayClasses.isEmpty()) {
                    val isWeekend = todayWeekday >= 6
                    hideAllFields(views)
                    views.setTextViewText(R.id.class_name_text,
                        if (isWeekend) "周末愉快～" else "啊？今天一节课都没有！")
                    views.setInt(R.id.location_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
                } else {
                    renderClassInfo(calendar, allPeriods, todayClasses, views)
                }

                attachClickIntent(context, views)

            } catch (e: Exception) {
                hideAllFields(views)
                views.setTextViewText(R.id.class_name_text, "数据解析失败")
                attachClickIntent(context, views)
            }
        }

        private fun renderExamInfo(data: JSONObject, views: RemoteViews) {
            val examLabel = data.optString("examLabel", "")
            val examName = data.optString("examName", "")
            val examTime = data.optString("examTime", "")
            val examDate = data.optString("examDate", "")
            val examDay = data.optString("examDay", "")
            val examRoom = data.optString("examRoom", "")

            if (examName.isNotEmpty()) {
                views.setInt(R.id.label_text, "setVisibility", 0x00000000)
                views.setTextViewText(R.id.label_text, examLabel)
                views.setInt(R.id.class_name_text, "setVisibility", 0x00000000)
                views.setTextViewText(R.id.class_name_text, examName)
                views.setInt(R.id.time_text, "setVisibility", 0x00000000)
                views.setTextViewText(R.id.time_text, "$examDate $examDay  $examTime")
                if (examRoom.isNotEmpty()) {
                    views.setInt(R.id.location_text, "setVisibility", 0x00000000)
                    views.setTextViewText(R.id.location_text, examRoom)
                } else {
                    views.setInt(R.id.location_text, "setVisibility", 0x00000008)
                }
                views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
            } else {
                hideAllFields(views)
                views.setTextViewText(R.id.class_name_text, "暂无考试")
            }
        }

        private fun hideAllFields(views: RemoteViews) {
            views.setInt(R.id.label_text, "setVisibility", 0x00000008)
            views.setInt(R.id.time_text, "setVisibility", 0x00000008)
            views.setInt(R.id.location_text, "setVisibility", 0x00000008)
            views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
        }

        private fun renderClassInfo(
            calendar: Calendar,
            allPeriods: JSONArray,
            todayClasses: List<JSONObject>,
            views: RemoteViews
        ) {
            data class TimedClass(
                val className: String,
                val teacherName: String,
                val locationName: String,
                val startMinute: Int,
                val endMinute: Int
            )

            val timedClasses = todayClasses.mapNotNull { cls ->
                val majorId = cls.optInt("period")
                var earliestStart = Int.MAX_VALUE
                var latestEnd = Int.MIN_VALUE

                for (i in 0 until allPeriods.length()) {
                    val period = allPeriods.getJSONObject(i)
                    if (period.optInt("majorId") != majorId) continue
                    val startStr = period.optString("minorStartTime")
                    val endStr = period.optString("minorEndTime")
                    if (startStr.isEmpty() || endStr.isEmpty()) continue

                    val sp = startStr.split(":")
                    val ep = endStr.split(":")
                    if (sp.size < 2 || ep.size < 2) continue
                    val sm = sp[0].toIntOrNull() ?: continue
                    val s = sm * 60 + (sp[1].toIntOrNull() ?: continue)
                    val em = ep[0].toIntOrNull() ?: continue
                    val e = em * 60 + (ep[1].toIntOrNull() ?: continue)

                    if (s < earliestStart) earliestStart = s
                    if (e > latestEnd) latestEnd = e
                }

                if (earliestStart == Int.MAX_VALUE) null
                else TimedClass(
                    className = cls.optString("className", ""),
                    teacherName = cls.optString("teacherName", ""),
                    locationName = cls.optString("locationName", ""),
                    startMinute = earliestStart,
                    endMinute = latestEnd
                )
            }.sortedBy { it.startMinute }

            if (timedClasses.isEmpty()) {
                hideAllFields(views)
                views.setTextViewText(R.id.class_name_text, "啊？今天一节课都没有！")
                return
            }

            val nowMinute = calendar.get(Calendar.HOUR_OF_DAY) * 60 +
                    calendar.get(Calendar.MINUTE)

            var currentClass: TimedClass? = null
            var nextClass: TimedClass? = null

            for (tc in timedClasses) {
                if (nowMinute >= tc.startMinute && nowMinute < tc.endMinute) {
                    currentClass = tc
                } else if (nowMinute < tc.startMinute && nextClass == null) {
                    nextClass = tc
                }
            }

            val target = currentClass ?: nextClass
            if (target != null) {
                val label = if (currentClass != null) "进行中" else "接下来"
                val timeRange = if (currentClass != null) {
                    "进行中 - ${formatTime(target.endMinute)}"
                } else {
                    "${formatTime(target.startMinute)} - ${formatTime(target.endMinute)}"
                }

                views.setInt(R.id.label_text, "setVisibility", 0x00000000)
                views.setTextViewText(R.id.label_text, label)
                views.setInt(R.id.time_text, "setVisibility", 0x00000000)
                views.setTextViewText(R.id.class_name_text, target.className)
                views.setTextViewText(R.id.time_text, timeRange)

                if (target.locationName.isNotEmpty()) {
                    views.setInt(R.id.location_text, "setVisibility", 0x00000000)
                    views.setTextViewText(R.id.location_text, target.locationName)
                } else {
                    views.setInt(R.id.location_text, "setVisibility", 0x00000008)
                }

                if (target.teacherName.isNotEmpty()) {
                    views.setInt(R.id.teacher_text, "setVisibility", 0x00000000)
                    views.setTextViewText(R.id.teacher_text, target.teacherName)
                } else {
                    views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
                }
            } else {
                hideAllFields(views)
                views.setTextViewText(R.id.class_name_text, "今天的课都上完啦～")
            }
        }

        private fun attachClickIntent(context: Context, views: RemoteViews) {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
            val pi = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pi)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_AUTO_REFRESH -> {
                updateAllWidgets(context)
                updateBackgroundRefresh(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        updateBackgroundRefresh(context)
    }

    override fun onDisabled(context: Context) {
        cancelAutoRefresh(context)
        WidgetRefreshWorker.cancel(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
    }
}
