// android/app/src/main/kotlin/com/example/safe_browser/MyAccessibilityService.kt
package com.example.safe_browser

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class MyAccessibilityService : AccessibilityService() {

    companion object {
        var isBlocking = false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isBlocking) return

        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString()
            
            // Jika window yang muncul bukan aplikasi kita
            if (packageName != null && packageName != "com.example.safe_browser" && packageName != "com.android.systemui") {
                relaunchApp()
            }
        }
    }

    private fun relaunchApp() {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(intent)
    }

    override fun onInterrupt() {}
}