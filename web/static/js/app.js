// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import 'phoenix_html';
import * as Views from './views';
import MainView from './views/main';

let currentView = null;

const getView = () => {
  const viewName = document.body.dataset.jsViewName;
  const View = Views[viewName];
  return View ? View : MainView;

}

const handleDOMContentLoaded = () => {
  const ViewClass = getView();
  const View = new ViewClass();
  View.mount();

  currentView = View;
};

const handleDocumentUnload = () => {
  currentView ? currentView.unmount() : null;
  currentView = null;
}

window.addEventListener('DOMContentLoaded', handleDOMContentLoaded, false);
window.addEventListener('unload', handleDocumentUnload, false);

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"
