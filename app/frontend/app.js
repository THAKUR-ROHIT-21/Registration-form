const form = document.getElementById("userForm");
const submitButton = document.getElementById("submitButton");
const formMessage = document.getElementById("formMessage");
const usersList = document.getElementById("usersList");
const searchInput = document.getElementById("searchInput");

let searchTimer;

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  })[character]);
}

async function loadUsers(search = "") {
  usersList.innerHTML = '<p class="empty-state">Loading users...</p>';

  try {
    const response = await fetch(`/api/users?search=${encodeURIComponent(search)}`);
    if (!response.ok) throw new Error("Unable to load users.");

    const users = await response.json();
    if (!users.length) {
      usersList.innerHTML = '<p class="empty-state">No users found.</p>';
      return;
    }

    usersList.innerHTML = users.map((user) => `
      <article class="user-item">
        <button class="delete-button" title="Delete user" onclick="deleteUser('${user.id}')">✕</button>
        <p><strong>Name:</strong> ${escapeHtml(user.name)}</p>
        <p><strong>City:</strong> ${escapeHtml(user.city)}</p>
        <p><strong>Degree:</strong> ${escapeHtml(user.degree)}</p>
      </article>
    `).join("");
  } catch (error) {
    usersList.innerHTML = `<p class="empty-state">${escapeHtml(error.message)}</p>`;
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  submitButton.disabled = true;
  formMessage.className = "message";
  formMessage.textContent = "Saving...";

  const payload = Object.fromEntries(new FormData(form).entries());

  try {
    const response = await fetch("/api/users", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Unable to save user.");

    form.reset();
    formMessage.className = "message success";
    formMessage.textContent = "User registered successfully.";
    await loadUsers(searchInput.value.trim());
  } catch (error) {
    formMessage.className = "message error";
    formMessage.textContent = error.message;
  } finally {
    submitButton.disabled = false;
  }
});

searchInput.addEventListener("input", () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => loadUsers(searchInput.value.trim()), 250);
});

async function deleteUser(id) {
  if (!confirm("Delete this user?")) return;

  const response = await fetch(`/api/users/${id}`, {method: "DELETE"});
  if (!response.ok) {
    const data = await response.json();
    alert(data.error || "Unable to delete user.");
    return;
  }
  await loadUsers(searchInput.value.trim());
}

window.deleteUser = deleteUser;
loadUsers();
