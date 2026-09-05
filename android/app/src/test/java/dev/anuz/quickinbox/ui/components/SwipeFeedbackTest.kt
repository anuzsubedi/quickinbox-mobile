package dev.anuz.quickinbox.ui.components

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SwipeFeedbackTest {
    @Test fun dispatchDoesNotWaitForAnimationTime() = runTest {
        val events = mutableListOf<String>()
        launch {
            completeSwipeFeedback(
                stillEnabled = { true },
                dispatch = { events += "mail action" },
                returnToRest = { events += "return"; delay(500); events += "rest" }
            )
        }
        runCurrent()
        assertEquals(0L, currentTime)
        assertEquals(listOf("mail action", "return"), events)
        advanceUntilIdle()
        assertEquals(listOf("mail action", "return", "rest"), events)
    }

    @Test fun disabledRowsDoNotDispatch() = runTest {
        var actions = 0
        var returned = false
        completeSwipeFeedback({ false }, { actions++ }, { returned = true })
        assertEquals(0, actions)
        assertTrue(returned)
    }

    @Test fun cancellingTheAnimationDoesNotLoseOrRepeatAnAcceptedAction() = runTest {
        var actions = 0
        val job = launch { completeSwipeFeedback({ true }, { actions++ }, { delay(500) }) }
        runCurrent()
        job.cancel()
        advanceUntilIdle()
        assertEquals(1, actions)
    }

    @Test fun nativeSpringBackCannotCoverTheCompletionPoseOrDoubleItsOffset() {
        for (displayed in listOf(-220f, 220f)) {
            for (native in listOf(-220f, -60f, 0f, 60f, 220f)) {
                assertEquals(displayed, native + swipeContentCompensation(native, displayed, true), 0.001f)
                assertEquals(0f, swipeContentCompensation(native, displayed, false), 0f)
            }
        }
    }

}
