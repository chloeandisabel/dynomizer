const CHANGE = 'change';

export default class ScheduleFormView {
  mount() {
    this.displayManagerFields();
    this.listenToTypeChange();
  }

  unmount() {
    this.stopListeningToTypeChange();
  }

  listenToTypeChange = () => {
    const el = document.getElementById('schedule_manager_type');
    if (el) {
      this.el = el;
      this.el.addEventListener(CHANGE, this.displayManagerFields);
    }
  }

  stopListeningToTypeChange = () => {
    if (this.el) {
      this.el.removeEventListener(CHANGE, this.displayManagerFields);
      delete this.el;
    }
  }

  showHide = (id, show, type) => {
    const el = document.getElementById(id);
    let  display, container;
    if (el) {
      if (type == "numeric") {
        display  = show ? "table-row" : "none";
        container = el.parentElement.parentElement;
      } else {
        display  = show ? "inline" : "none";
        container = el.parentElement;
      }
      container.style.display = display;
    }
  }

  displayManagerFields = () => {
    for (let i in NON_NUMERIC_FIELDS) {
      this.showHide("schedule_" + NON_NUMERIC_FIELDS[i], false, "non_numeric");
    }
    for (let i in NUMERIC_FIELDS) {
      this.showHide("schedule_numeric_parameters_" + i + "_rule", false, "numeric");
    }
    const type = document.getElementById("schedule_manager_type").value;
    if (type != undefined && type != "") {
      for (let i in MANAGER_FIELDS[type]["non_numeric"]) {
        this.showHide("schedule_" + MANAGER_FIELDS[type]["non_numeric"][i], true, "non_numeric");
      }
      for (let i in MANAGER_FIELDS[type]["numeric"]) {
        this.showHide("schedule_numeric_parameters_" + i + "_rule", true, "numeric");
      }
    }
  }
};
