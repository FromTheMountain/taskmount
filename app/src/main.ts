import './assets/main.css'

import { createApp } from 'vue'
import { library } from '@fortawesome/fontawesome-svg-core'
import { faPencil, faPlus } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'
import App from './App.vue'

library.add(faPencil)
library.add(faPlus)

createApp(App)
  .component('font-awesome-icon', FontAwesomeIcon)
  .mount('#app')
