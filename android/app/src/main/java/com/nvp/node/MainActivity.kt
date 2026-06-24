package com.nvp.node

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nvp.node.ui.RootScaffold
import com.nvp.node.ui.theme.NvpTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Config.init(applicationContext)
        setContent {
            NvpTheme {
                val app: AppState = viewModel()
                RootScaffold(app)
            }
        }
    }
}
