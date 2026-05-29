// Add your LiveView hooks here.
//
// Usage in HEEx:
//   <div phx-hook="MyHook" id="my-element">...</div>
//
// Each hook must have a unique `id` attribute on the element.

// Example:
// const MyHook = {
//   mounted() { console.log("mounted", this.el) },
//   updated() {},
//   destroyed() {},
// }

// Auto-focus an input/textarea when it mounts and select all text.
// Used for click-to-edit fields so the user can type immediately.
const AutoFocus = {
  mounted() {
    this.el.focus()
    // Move cursor to end (same as Livebook headline behavior)
    const len = this.el.value.length
    this.el.setSelectionRange(len, len)
  }
}

export default {
  AutoFocus,
}
