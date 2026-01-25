import { supabaseClient } from '../supabase-config.js';
import { showToast, formatDate } from '../utils.js';

let currentDate = new Date();
let selectedDate = new Date();
let sessionsCache = [];

export async function loadClasses() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Eğitmen Programı</h2>
            <div class="calendar-nav">
                <button id="prev-month" class="nav-btn">❮</button>
                <h3 id="current-month-year">Ocak 2026</h3>
                <button id="next-month" class="nav-btn">❯</button>
            </div>
        </div>
        
        <div class="schedule-layout">
            <!-- Calendar Card -->
            <div class="calendar-container">
                <div class="calendar-header-days">
                    <div>Pzt</div><div>Sal</div><div>Çar</div><div>Per</div><div>Cum</div><div>Cmt</div><div>Paz</div>
                </div>
                <div id="calendar-grid" class="calendar-grid">
                    <!-- Days will be injected here -->
                </div>
            </div>

            <!-- Selected Day Sessions -->
            <div class="day-sessions-container">
                <div class="day-header" id="selected-day-header">
                    Bugünkü Program
                </div>
                <div id="day-sessions-list" class="sessions-list">
                    <div class="text-center text-secondary">Yükleniyor...</div>
                </div>
            </div>
        </div>

        <style>
            .schedule-layout {
                display: flex;
                flex-direction: column;
                gap: 24px;
                max-width: 600px;
                margin: 0 auto;
            }

            .module-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 24px;
            }

            .calendar-nav {
                display: flex;
                align-items: center;
                gap: 16px;
            }

            .nav-btn {
                background: rgba(255,255,255,0.1);
                border: none;
                color: var(--text-primary);
                width: 32px;
                height: 32px;
                border-radius: 8px;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
                transition: background 0.2s;
            }
            .nav-btn:hover {
                background: rgba(255,255,255,0.2);
            }

            /* Calendar Container (Dark Card) */
            .calendar-container {
                background: #1C1C1E; /* Dark gray similar to screenshot */
                border-radius: 20px;
                padding: 20px;
                border: 1px solid rgba(255,255,255,0.1);
            }

            .calendar-header-days {
                display: grid;
                grid-template-columns: repeat(7, 1fr);
                text-align: center;
                color: var(--text-secondary);
                font-size: 14px;
                margin-bottom: 16px;
            }

            .calendar-grid {
                display: grid;
                grid-template-columns: repeat(7, 1fr);
                gap: 8px;
            }

            .calendar-day {
                aspect-ratio: 1;
                display: flex;
                align-items: center;
                justify-content: center;
                border-radius: 50%; /* Circle shape as in screenshot */
                cursor: pointer;
                font-size: 15px;
                color: var(--text-primary);
                position: relative;
                transition: all 0.2s ease;
            }

            .calendar-day:hover {
                background: rgba(255,255,255,0.1);
            }

            .calendar-day.other-month {
                color: rgba(255,255,255,0.2);
            }

            .calendar-day.selected {
                background: var(--primary-yellow);
                color: #000;
                font-weight: 700;
                box-shadow: 0 0 10px rgba(255, 215, 0, 0.4);
            }

            .calendar-day.has-event::after {
                content: '';
                position: absolute;
                bottom: 6px;
                width: 4px;
                height: 4px;
                background: var(--neon-cyan);
                border-radius: 50%;
            }

            .calendar-day.selected.has-event::after {
                background: #000;
            }

            /* Sessions List */
            .day-sessions-container {
                margin-top: 10px;
            }
            .day-header {
                font-size: 18px;
                font-weight: 600;
                margin-bottom: 16px;
                color: var(--text-primary);
            }

            .session-card {
                background: #1C1C1E;
                border-radius: 16px;
                padding: 16px;
                margin-bottom: 12px;
                border-left: 3px solid var(--text-secondary); /* Default generic */
                display: flex;
                flex-direction: column;
                gap: 8px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            }

            .session-time {
                color: var(--primary-yellow);
                font-weight: 700;
                font-size: 18px;
            }

            .session-title {
                font-size: 16px;
                font-weight: 600;
                color: #fff;
            }

            .session-trainer {
                display: flex;
                align-items: center;
                gap: 8px;
                font-size: 14px;
                color: var(--neon-cyan);
            }
            
            .text-secondary { color: var(--text-secondary); }
            .text-center { text-align: center; }

        </style>
    `;

    // Initialize logic
    setupEventListeners();
    await fetchMonthSessions(currentDate);
    renderCalendar();
    renderDaySessions(selectedDate);
}

function setupEventListeners() {
    document.getElementById('prev-month').addEventListener('click', () => {
        currentDate.setMonth(currentDate.getMonth() - 1);
        handleMonthChange();
    });

    document.getElementById('next-month').addEventListener('click', () => {
        currentDate.setMonth(currentDate.getMonth() + 1);
        handleMonthChange();
    });
}

async function handleMonthChange() {
    renderCalendar(); // Re-render first (empty/loading visual if needed)
    await fetchMonthSessions(currentDate);
    renderCalendar(); // Re-render with dots
}

async function fetchMonthSessions(date) {
    const year = date.getFullYear();
    const month = date.getMonth();

    // Start of month
    const start = new Date(year, month, 1).toISOString();
    // End of month
    const end = new Date(year, month + 1, 0, 23, 59, 59).toISOString();

    try {
        const { data: { user } } = await supabaseClient.auth.getUser();
        // Assuming trainer_id is meaningful for current org, or fetch all for org
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        // Fetch sessions in range
        // Join with trainer info
        const { data, error } = await supabaseClient
            .from('class_sessions')
            .select(`
                id,
                title,
                start_time,
                end_time,
                trainer:trainer_id (first_name, last_name)
            `)
            .gte('start_time', start)
            .lte('start_time', end)
            .order('start_time', { ascending: true });

        if (error) {
            console.error('Error fetching sessions:', error);
            showToast('Ders programı yüklenemedi', 'error');
            return;
        }

        sessionsCache = data || [];

    } catch (err) {
        console.error(err);
    }
}

function renderCalendar() {
    const grid = document.getElementById('calendar-grid');
    if (!grid) return; // Stop if user navigated away

    const monthLabel = document.getElementById('current-month-year');

    // Update Header
    const monthNames = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
    monthLabel.textContent = `${monthNames[currentDate.getMonth()]} ${currentDate.getFullYear()}`;

    grid.innerHTML = '';

    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();

    const firstDay = new Date(year, month, 1).getDay(); // 0 = Sun
    // Adjust for Monday start (Turkey)
    // Mon=1..Sun=7, in JS Sun=0. So we want Mon=0..Sun=6
    // JS: Sun=0, Mon=1...
    // Target: Mon(1) -> 0, Tue(2) -> 1 ... Sun(0) -> 6
    const startDayIndex = (firstDay === 0 ? 6 : firstDay - 1);

    const daysInMonth = new Date(year, month + 1, 0).getDate();

    // Prev Month Filler
    const prevMonthDays = new Date(year, month, 0).getDate();
    for (let i = startDayIndex - 1; i >= 0; i--) {
        const dayDiv = document.createElement('div');
        dayDiv.className = 'calendar-day other-month';
        dayDiv.textContent = prevMonthDays - i;
        grid.appendChild(dayDiv);
    }

    // Current Month Days
    for (let i = 1; i <= daysInMonth; i++) {
        const dayDiv = document.createElement('div');
        dayDiv.className = 'calendar-day';
        dayDiv.textContent = i;

        // Check date match
        const thisDateStr = new Date(year, month, i).toDateString();
        if (thisDateStr === selectedDate.toDateString()) {
            dayDiv.classList.add('selected');
        }

        // Check events
        const hasEvent = sessionsCache.some(s => {
            const sDate = new Date(s.start_time);
            return sDate.getDate() === i && sDate.getMonth() === month && sDate.getFullYear() === year;
        });

        if (hasEvent) dayDiv.classList.add('has-event');

        dayDiv.addEventListener('click', () => {
            // Update selection
            document.querySelectorAll('.calendar-day').forEach(d => d.classList.remove('selected'));
            dayDiv.classList.add('selected');
            selectedDate = new Date(year, month, i);
            renderDaySessions(selectedDate);
        });

        grid.appendChild(dayDiv);
    }
}

function renderDaySessions(date) {
    const listContainer = document.getElementById('day-sessions-list');
    const header = document.getElementById('selected-day-header');

    // Format Header Date
    const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    header.textContent = date.toLocaleDateString('tr-TR', options);

    // Filter sessions
    const daySessions = sessionsCache.filter(s => {
        const sDate = new Date(s.start_time);
        return sDate.toDateString() === date.toDateString();
    });

    if (daySessions.length === 0) {
        listContainer.innerHTML = `
            <div style="padding: 20px; text-align: center; color: var(--text-secondary); background: #1C1C1E; border-radius: 16px;">
                <div style="font-size: 40px; margin-bottom: 10px;">📅</div>
                <div>Bu tarihte planlanmış ders yok.</div>
            </div>
        `;
        return;
    }

    listContainer.innerHTML = daySessions.map(session => {
        const start = new Date(session.start_time).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
        const end = new Date(session.end_time).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });

        return `
            <div class="session-card">
                <div class="session-time">${start} - ${end}</div>
                <div class="session-title">${session.title || 'Ders'}</div>
                <div class="session-trainer">
                    👤 ${session.trainer ? (session.trainer.first_name + ' ' + session.trainer.last_name) : 'Eğitmen Yok'}
                </div>
            </div>
        `;
    }).join('');
}
