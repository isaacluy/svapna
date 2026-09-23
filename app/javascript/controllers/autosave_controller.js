import { Controller } from "@hotwired/stimulus"

// Saves the composer as you write.
//
// Deliberately an enhancement, not a requirement: the form has a real submit
// button and works fully without this controller. If the fetch fails the button
// is still there, and the status line says so rather than pretending.
export default class extends Controller {
  static targets = ["form", "status", "body", "publish"]
  static values = {
    delay: { type: Number, default: 2000 },
    updateUrl: String
  }

  connect() {
    this.timer = null
    this.saving = false
    this.dirty = false
    this.boundFlush = this.flush.bind(this)

    // A save that has not fired yet would be lost on navigation.
    document.addEventListener("visibilitychange", this.boundFlush)
    window.addEventListener("pagehide", this.boundFlush)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("visibilitychange", this.boundFlush)
    window.removeEventListener("pagehide", this.boundFlush)
  }

  // data-action="input->autosave#schedule change->autosave#schedule"
  schedule() {
    this.dirty = true
    this.setStatus("Unsaved changes", "muted")
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  flush() {
    if (document.visibilityState === "hidden" && this.dirty) this.save()
  }

  async save() {
    clearTimeout(this.timer)

    // The body is required, so autosaving an empty entry would only ever
    // produce a validation error. Wait until there is something to keep.
    if (!this.hasBodyTarget || this.bodyTarget.value.trim() === "") return
    if (this.saving) { this.dirty = true; return }

    this.saving = true
    this.dirty = false
    this.setStatus("Saving…", "muted")

    try {
      const response = await fetch(this.formTarget.action, {
        method: this.formMethod(),
        headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken() },
        body: new FormData(this.formTarget)
      })

      if (response.ok) {
        this.adopt(await response.json())
      } else if (response.status === 422) {
        const { errors } = await response.json()
        this.setStatus(errors?.[0] || "Could not save", "warn")
      } else {
        this.setStatus("Could not save", "warn")
      }
    } catch {
      this.setStatus("Offline — use Save", "warn")
    } finally {
      this.saving = false
      if (this.dirty) this.schedule()
    }
  }

  // After the first save a new entry has an id, so later saves must PATCH it
  // rather than POSTing another copy.
  adopt(payload) {
    if (payload.update_url && this.formTarget.action !== payload.update_url) {
      this.formTarget.action = payload.update_url
      this.setMethodOverride("patch")
      history.replaceState({}, "", payload.edit_url)

      // The publish button was rendered before the entry had an id, so point it
      // at the real one and let it work.
      if (this.hasPublishTarget) {
        const form = this.publishTarget.querySelector("form")
        if (form) form.action = payload.publish_url
        this.publishTarget.querySelectorAll("button").forEach((b) => (b.disabled = false))
        this.publishTarget.hidden = false
      }
    }

    const at = new Date(payload.saved_at)
    const time = at.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    this.setStatus(`Saved ${time}`, "ok")
  }

  setMethodOverride(verb) {
    let field = this.formTarget.querySelector("input[name='_method']")

    if (!field) {
      field = document.createElement("input")
      field.type = "hidden"
      field.name = "_method"
      this.formTarget.prepend(field)
    }

    field.value = verb
  }

  formMethod() {
    const override = this.formTarget.querySelector("input[name='_method']")
    return override ? "POST" : this.formTarget.method.toUpperCase()
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  setStatus(text, tone) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = text
    this.statusTarget.dataset.tone = tone
  }
}
