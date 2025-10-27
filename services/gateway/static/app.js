// Global state
let authToken = localStorage.getItem('authToken');
let currentUser = null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    if (authToken) {
        loadUserProfile();
    }
    
    // Enter key for search
    document.getElementById('searchInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') search();
    });
});

// =====================================================
// Authentication
// =====================================================
function showLogin() {
    document.getElementById('loginModal').style.display = 'flex';
}

function showRegister() {
    document.getElementById('registerModal').style.display = 'flex';
}

function closeModal(modalId) {
    document.getElementById(modalId).style.display = 'none';
}

async function register() {
    const email = document.getElementById('regEmail').value;
    const username = document.getElementById('regUsername').value;
    const password = document.getElementById('regPassword').value;
    const full_name = document.getElementById('regFullname').value;
    
    const errorDiv = document.getElementById('registerError');
    
    if (!email || !username || !password) {
        errorDiv.textContent = 'Заполните все обязательные поля';
        return;
    }
    
    try {
        const response = await fetch('/api/users/register', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({email, username, password, full_name})
        });
        
        if (response.ok) {
            errorDiv.style.color = '#28a745';
            errorDiv.textContent = 'Регистрация успешна! Войдите в систему.';
            setTimeout(() => {
                closeModal('registerModal');
                showLogin();
            }, 1500);
        } else {
            const error = await response.json();
            errorDiv.textContent = error.detail || 'Ошибка регистрации';
        }
    } catch (err) {
        errorDiv.textContent = 'Ошибка соединения с сервером';
    }
}

async function login() {
    const username = document.getElementById('loginUsername').value;
    const password = document.getElementById('loginPassword').value;
    
    const errorDiv = document.getElementById('loginError');
    
    if (!username || !password) {
        errorDiv.textContent = 'Заполните все поля';
        return;
    }
    
    try {
        const response = await fetch('/api/users/login', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({username, password})
        });
        
        if (response.ok) {
            const data = await response.json();
            authToken = data.access_token;
            localStorage.setItem('authToken', authToken);
            closeModal('loginModal');
            await loadUserProfile();
        } else {
            const error = await response.json();
            errorDiv.textContent = error.detail || 'Ошибка входа';
        }
    } catch (err) {
        errorDiv.textContent = 'Ошибка соединения с сервером';
    }
}

async function loadUserProfile() {
    try {
        const response = await fetch('/api/users/profile', {
            headers: {'Authorization': `Bearer ${authToken}`}
        });
        
        if (response.ok) {
            currentUser = await response.json();
            document.getElementById('authButtons').style.display = 'none';
            document.getElementById('userInfo').style.display = 'block';
            document.getElementById('username').textContent = currentUser.username;
        } else {
            logout();
        }
    } catch (err) {
        console.error('Failed to load profile:', err);
    }
}

function logout() {
    authToken = null;
    currentUser = null;
    localStorage.removeItem('authToken');
    document.getElementById('authButtons').style.display = 'block';
    document.getElementById('userInfo').style.display = 'none';
}

// =====================================================
// Search
// =====================================================
async function search() {
    const query = document.getElementById('searchInput').value.trim();
    const resultsDiv = document.getElementById('searchResults');
    
    if (!query) {
        resultsDiv.innerHTML = '<p class="empty-state">Введите поисковый запрос</p>';
        return;
    }
    
    resultsDiv.innerHTML = '<p class="loading">Поиск...</p>';
    
    try {
        const startTime = Date.now();
        const response = await fetch(`/api/search?q=${encodeURIComponent(query)}&limit=10`);
        const elapsed = Date.now() - startTime;
        
        if (response.ok) {
            const data = await response.json();
            displaySearchResults(data, elapsed);
        } else {
            resultsDiv.innerHTML = '<p class="error">Ошибка поиска</p>';
        }
    } catch (err) {
        resultsDiv.innerHTML = '<p class="error">Ошибка соединения с сервером</p>';
    }
}

function displaySearchResults(data, clientTime) {
    const resultsDiv = document.getElementById('searchResults');
    
    if (data.results.length === 0) {
        resultsDiv.innerHTML = '<p class="empty-state">Ничего не найдено</p>';
        return;
    }
    
    const cacheStatus = data.cached 
        ? '<span class="badge badge-cached">Из кэша</span>'
        : '<span class="badge badge-fresh">Из БД</span>';
    
    let html = `
        <div style="margin-bottom: 20px; color: #666;">
            Найдено: <strong>${data.total}</strong> результатов
            | Время: <strong>${data.query_time_ms.toFixed(2)} мс</strong> (сервер)
            + <strong>${clientTime} мс</strong> (сеть)
            ${cacheStatus}
        </div>
    `;
    
    data.results.forEach(result => {
        html += `
            <div class="search-result">
                <h4>${escapeHtml(result.title)}</h4>
                <p>${escapeHtml(result.snippet)}</p>
                <div class="meta">
                    Релевантность: ${(result.score * 100).toFixed(1)}%
                    | Индексировано: ${new Date(result.indexed_at).toLocaleString('ru-RU')}
                </div>
            </div>
        `;
    });
    
    resultsDiv.innerHTML = html;
}

// =====================================================
// Documents
// =====================================================
async function createDocument() {
    const title = document.getElementById('docTitle').value.trim();
    const content = document.getElementById('docContent').value.trim();
    const author = document.getElementById('docAuthor').value.trim();
    
    if (!title || !content) {
        alert('Заполните заголовок и содержание');
        return;
    }
    
    try {
        const response = await fetch('/api/documents', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(authToken && {'Authorization': `Bearer ${authToken}`})
            },
            body: JSON.stringify({title, content, author: author || null})
        });
        
        if (response.ok) {
            document.getElementById('docTitle').value = '';
            document.getElementById('docContent').value = '';
            document.getElementById('docAuthor').value = '';
            alert('Документ создан! Индексация началась.');
            loadDocuments();
        } else {
            const error = await response.json();
            alert('Ошибка: ' + (error.detail || 'Не удалось создать документ'));
        }
    } catch (err) {
        alert('Ошибка соединения с сервером');
    }
}

async function loadDocuments() {
    const listDiv = document.getElementById('documentsList');
    listDiv.innerHTML = '<p class="loading">Загрузка...</p>';
    
    try {
        const response = await fetch('/api/documents?limit=20');
        
        if (response.ok) {
            const documents = await response.json();
            displayDocuments(documents);
        } else {
            listDiv.innerHTML = '<p class="error">Ошибка загрузки документов</p>';
        }
    } catch (err) {
        listDiv.innerHTML = '<p class="error">Ошибка соединения с сервером</p>';
    }
}

function displayDocuments(documents) {
    const listDiv = document.getElementById('documentsList');
    
    if (documents.length === 0) {
        listDiv.innerHTML = '<p class="empty-state">Нет документов</p>';
        return;
    }
    
    let html = '';
    documents.forEach(doc => {
        const indexedBadge = doc.indexed 
            ? '<span class="badge badge-cached">Индексирован</span>'
            : '<span class="badge" style="background: #ffc107; color: black;">Ожидает индексации</span>';
        
        const snippet = doc.content.length > 150 
            ? doc.content.substring(0, 150) + '...'
            : doc.content;
        
        html += `
            <div class="document-item">
                <h4>${escapeHtml(doc.title)} ${indexedBadge}</h4>
                <p>${escapeHtml(snippet)}</p>
                <div class="meta">
                    ID: ${doc.id} | 
                    Автор: ${escapeHtml(doc.author || 'Не указан')} | 
                    Создано: ${new Date(doc.created_at).toLocaleString('ru-RU')}
                </div>
            </div>
        `;
    });
    
    listDiv.innerHTML = html;
}

// =====================================================
// Utilities
// =====================================================
function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, m => map[m]);
}
