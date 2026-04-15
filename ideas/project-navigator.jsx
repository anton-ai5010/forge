import { useState } from "react";

const ACCENT = "#4dd0e1";
const BG = "#0d1117";
const CARD = "#161b22";
const BORDER = "#30363d";
const DIM = "#7d8590";
const TEXT = "#e6edf3";
const GREEN = "#3fb950";
const YELLOW = "#d29922";
const RED = "#f85149";
const BLUE = "#58a6ff";
const PURPLE = "#bc8cff";

const project = {
  name: "YARICK",
  goal: "Зарабатывать на ставках, предсказывая тоталы футбольных матчей",
  entities: [
    {
      id: "match",
      label: "Матчи",
      icon: "⚽",
      color: GREEN,
      oneLiner: "Данные о прошедших играх",
      details: {
        what: "Записи о футбольных матчах — кто играл, счёт, коэффициенты букмекеров",
        analogy: "Как строки в Excel-таблице. Одна строка = один матч.",
        hasWhat: ["Команды (дом/гость)", "Лига и дата", "Итоговый счёт", "Коэфы букмекера на тотал"],
        whereFrom: "Скачиваются из football-data.co.uk",
        count: "~534 000 матчей",
        status: "ok",
        statusText: "Данные загружены, 22 лиги из 55",
      },
    },
    {
      id: "features",
      label: "Признаки",
      icon: "📐",
      color: YELLOW,
      oneLiner: "Числа, по которым модель принимает решение",
      details: {
        what: "Посчитанные показатели из истории матчей — «средний тотал дома за 10 игр» и т.п.",
        analogy: "Как характеристики товара на маркетплейсе. Модель смотрит на них и решает — брать или нет.",
        hasWhat: ["Название признака", "Формула расчёта", "Числовое значение"],
        whereFrom: "Считаются автоматически из матчей",
        count: "131 штука на каждый матч",
        status: "ok",
        statusText: "Рассчитаны",
      },
    },
    {
      id: "model",
      label: "Модель",
      icon: "🧠",
      color: BLUE,
      oneLiner: "Алгоритм, который предсказывает результат",
      details: {
        what: "9 обученных XGBoost-моделей, которые смотрят на признаки и говорят: тотал больше или меньше 2.5",
        analogy: "Как опытный аналитик, который смотрит на статистику и делает прогноз. Только их 9, и они голосуют.",
        hasWhat: ["На каких лигах обучена", "Точность предсказаний", "Версия и дата"],
        whereFrom: "Обучается на исторических данных + признаках",
        count: "9 моделей (ансамбль — голосование большинством)",
        status: "warn",
        statusText: "Нужна проверка реального edge (CLV)",
      },
    },
    {
      id: "prediction",
      label: "Прогноз",
      icon: "🎯",
      color: PURPLE,
      oneLiner: "Конечный результат — ставить или нет",
      details: {
        what: "Решение системы по конкретному матчу: вероятность, уверенность, рекомендация",
        analogy: "Как итоговый вердикт врача: диагноз + рекомендация к лечению + степень уверенности.",
        hasWhat: ["Вероятность over/under", "Уровень уверенности", "Ставить или пропустить", "Размер ставки"],
        whereFrom: "Модель + признаки нового матча → прогноз",
        count: "1 на каждый матч",
        status: "warn",
        statusText: "Пайплайн не собран до конца",
      },
    },
  ],
  flow: [
    { from: 0, to: 1, label: "считаем признаки" },
    { from: 1, to: 2, label: "обучаем модель" },
    { from: 2, to: 3, label: "делаем прогноз" },
  ],
  processes: [
    {
      label: "Загрузка данных",
      icon: "📥",
      desc: "Скачать CSV → положить в базу",
      input: "Матчи",
      output: "Матчи",
      status: "ok",
    },
    {
      label: "Расчёт признаков",
      icon: "⚙️",
      desc: "Пройтись по матчам → посчитать 131 число на каждый",
      input: "Матчи",
      output: "Признаки",
      status: "ok",
    },
    {
      label: "Обучение",
      icon: "📚",
      desc: "Показать модели историю → она учится предсказывать",
      input: "Признаки",
      output: "Модель",
      status: "ok",
    },
    {
      label: "Прогноз",
      icon: "🔮",
      desc: "Новый матч → модель говорит вероятность",
      input: "Модель + новые признаки",
      output: "Прогноз",
      status: "warn",
    },
    {
      label: "Бэктест",
      icon: "📊",
      desc: "Проверить на прошлом: а реально ли модель зарабатывает?",
      input: "История прогнозов",
      output: "ROI, прибыль/убыток",
      status: "err",
    },
  ],
};

const statusIcon = (s) =>
  s === "ok" ? "✅" : s === "warn" ? "⚠️" : "❌";
const statusColor = (s) =>
  s === "ok" ? GREEN : s === "warn" ? YELLOW : RED;
const statusLabel = (s) =>
  s === "ok" ? "Готово" : s === "warn" ? "Частично" : "Не готово";

function EntityCard({ e, selected, onClick }) {
  const active = selected;
  return (
    <div
      onClick={onClick}
      style={{
        background: active ? `${e.color}15` : CARD,
        border: `2px solid ${active ? e.color : BORDER}`,
        borderRadius: 14,
        padding: "16px 18px",
        cursor: "pointer",
        transition: "all 0.25s ease",
        transform: active ? "scale(1.02)" : "scale(1)",
        position: "relative",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
        <span style={{ fontSize: 28 }}>{e.icon}</span>
        <div>
          <div style={{ fontSize: 17, fontWeight: 700, color: TEXT }}>{e.label}</div>
          <div style={{ fontSize: 12, color: DIM }}>{e.oneLiner}</div>
        </div>
        <span style={{ marginLeft: "auto", fontSize: 16 }}>
          {statusIcon(e.details.status)}
        </span>
      </div>
      {!active && (
        <div style={{ fontSize: 11, color: `${e.color}aa`, marginTop: 4 }}>
          Нажми чтобы раскрыть →
        </div>
      )}
    </div>
  );
}

function EntityDetails({ e }) {
  const d = e.details;
  const sectionStyle = { marginBottom: 16 };
  const labelStyle = {
    fontSize: 11, color: DIM, textTransform: "uppercase",
    letterSpacing: 1, marginBottom: 6, fontWeight: 600,
  };
  return (
    <div
      style={{
        background: `${e.color}08`,
        border: `1px solid ${e.color}30`,
        borderRadius: 14,
        padding: 20,
        animation: "fadeIn 0.3s ease",
      }}
    >
      {/* Что это */}
      <div style={sectionStyle}>
        <div style={labelStyle}>Что это простыми словами</div>
        <div style={{ fontSize: 14, color: TEXT, lineHeight: 1.5 }}>{d.what}</div>
      </div>

      {/* Аналогия */}
      <div style={{
        ...sectionStyle, background: `${e.color}10`, borderRadius: 10,
        padding: "12px 14px", borderLeft: `3px solid ${e.color}`,
      }}>
        <div style={{ fontSize: 11, color: e.color, fontWeight: 600, marginBottom: 4 }}>
          💡 АНАЛОГИЯ
        </div>
        <div style={{ fontSize: 13, color: TEXT, lineHeight: 1.5 }}>{d.analogy}</div>
      </div>

      {/* Что у него есть */}
      <div style={sectionStyle}>
        <div style={labelStyle}>Что у него внутри</div>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
          {d.hasWhat.map((a, i) => (
            <span key={i} style={{
              fontSize: 12, background: `${e.color}18`, color: TEXT,
              padding: "5px 10px", borderRadius: 6,
              border: `1px solid ${e.color}25`,
            }}>{a}</span>
          ))}
        </div>
      </div>

      {/* Откуда + Сколько */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 16 }}>
        <div style={{
          background: CARD, borderRadius: 10, padding: "10px 14px",
          border: `1px solid ${BORDER}`,
        }}>
          <div style={{ fontSize: 10, color: DIM, marginBottom: 3 }}>ОТКУДА БЕРЁТСЯ</div>
          <div style={{ fontSize: 13, color: ACCENT }}>{d.whereFrom}</div>
        </div>
        <div style={{
          background: CARD, borderRadius: 10, padding: "10px 14px",
          border: `1px solid ${BORDER}`,
        }}>
          <div style={{ fontSize: 10, color: DIM, marginBottom: 3 }}>СКОЛЬКО</div>
          <div style={{ fontSize: 13, color: ACCENT }}>{d.count}</div>
        </div>
      </div>

      {/* Статус */}
      <div style={{
        display: "flex", alignItems: "center", gap: 8,
        padding: "8px 12px", borderRadius: 8,
        background: `${statusColor(d.status)}15`,
        border: `1px solid ${statusColor(d.status)}30`,
      }}>
        <span style={{ fontSize: 16 }}>{statusIcon(d.status)}</span>
        <span style={{ fontSize: 12, color: statusColor(d.status), fontWeight: 600 }}>
          {statusLabel(d.status)}
        </span>
        <span style={{ fontSize: 12, color: DIM, marginLeft: 4 }}>{d.statusText}</span>
      </div>
    </div>
  );
}

function FlowArrow({ label, color }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", justifyContent: "center",
      padding: "4px 0", color: DIM,
    }}>
      <div style={{
        width: 2, height: 20, background: `${color || DIM}40`,
      }} />
      <span style={{
        position: "absolute", fontSize: 11, color: `${color || DIM}`,
        background: BG, padding: "0 8px", transform: "translateX(30px)",
      }}>{label}</span>
    </div>
  );
}

function ProcessRow({ p }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 12,
      padding: "10px 14px", borderRadius: 10,
      background: CARD, border: `1px solid ${BORDER}`,
    }}>
      <span style={{ fontSize: 22 }}>{p.icon}</span>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: TEXT }}>{p.label}</div>
        <div style={{ fontSize: 12, color: DIM }}>{p.desc}</div>
      </div>
      <div style={{ textAlign: "right" }}>
        <div style={{ fontSize: 11, color: ACCENT }}>{p.input} → {p.output}</div>
        <div style={{
          fontSize: 11, color: statusColor(p.status),
          display: "flex", alignItems: "center", gap: 4, justifyContent: "flex-end",
        }}>
          {statusIcon(p.status)} {statusLabel(p.status)}
        </div>
      </div>
    </div>
  );
}

export default function ProjectNavigator() {
  const [view, setView] = useState("map"); // map | process
  const [selected, setSelected] = useState(null);

  return (
    <div style={{
      background: BG, color: TEXT, minHeight: "100vh",
      fontFamily: "'DM Sans', -apple-system, sans-serif",
      padding: "20px 16px",
    }}>
      <style>{`@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }`}</style>

      <div style={{ maxWidth: 600, margin: "0 auto" }}>
        {/* Header */}
        <div style={{ marginBottom: 20 }}>
          <div style={{
            fontSize: 13, color: DIM, textTransform: "uppercase",
            letterSpacing: 2, marginBottom: 4,
          }}>
            Навигатор проекта
          </div>
          <div style={{ fontSize: 24, fontWeight: 800, color: TEXT }}>
            {project.name}
          </div>
          <div style={{
            fontSize: 14, color: ACCENT, marginTop: 4,
            padding: "8px 12px", background: `${ACCENT}10`,
            borderRadius: 8, borderLeft: `3px solid ${ACCENT}`,
          }}>
            🎯 {project.goal}
          </div>
        </div>

        {/* Tabs */}
        <div style={{
          display: "flex", gap: 4, marginBottom: 20,
          background: CARD, borderRadius: 10, padding: 3,
        }}>
          {[
            { id: "map", label: "🗺 Из чего состоит" },
            { id: "process", label: "⚡ Что происходит" },
          ].map((t) => (
            <button
              key={t.id}
              onClick={() => { setView(t.id); setSelected(null); }}
              style={{
                flex: 1, padding: "10px 0", border: "none", borderRadius: 8,
                fontSize: 14, fontWeight: 600, cursor: "pointer",
                background: view === t.id ? ACCENT : "transparent",
                color: view === t.id ? BG : DIM,
                transition: "all 0.2s",
              }}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* MAP VIEW */}
        {view === "map" && (
          <div>
            <div style={{ fontSize: 12, color: DIM, marginBottom: 12 }}>
              Нажми на любой блок чтобы узнать подробности
            </div>

            {project.entities.map((e, i) => (
              <div key={e.id}>
                <EntityCard
                  e={e}
                  selected={selected === i}
                  onClick={() => setSelected(selected === i ? null : i)}
                />

                {selected === i && (
                  <div style={{ margin: "8px 0", animation: "fadeIn 0.3s ease" }}>
                    <EntityDetails e={e} />
                  </div>
                )}

                {i < project.entities.length - 1 && (
                  <div style={{
                    display: "flex", flexDirection: "column",
                    alignItems: "center", padding: "6px 0",
                  }}>
                    <div style={{
                      fontSize: 11, color: project.entities[i].color,
                      background: `${project.entities[i].color}15`,
                      padding: "3px 12px", borderRadius: 20,
                    }}>
                      ↓ {project.flow[i]?.label}
                    </div>
                  </div>
                )}
              </div>
            ))}

            {/* Legend */}
            <div style={{
              marginTop: 20, padding: 14, borderRadius: 10,
              background: CARD, border: `1px solid ${BORDER}`,
            }}>
              <div style={{ fontSize: 11, color: DIM, marginBottom: 8, fontWeight: 600 }}>
                ОБОЗНАЧЕНИЯ
              </div>
              <div style={{ display: "flex", gap: 16, flexWrap: "wrap" }}>
                {[
                  { icon: "✅", label: "Готово", color: GREEN },
                  { icon: "⚠️", label: "Частично", color: YELLOW },
                  { icon: "❌", label: "Не готово", color: RED },
                ].map((s) => (
                  <div key={s.label} style={{
                    display: "flex", alignItems: "center", gap: 4,
                    fontSize: 12, color: s.color,
                  }}>
                    {s.icon} {s.label}
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* PROCESS VIEW */}
        {view === "process" && (
          <div>
            <div style={{ fontSize: 12, color: DIM, marginBottom: 12 }}>
              Порядок действий в системе — сверху вниз
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
              {project.processes.map((p, i) => (
                <div key={i}>
                  <ProcessRow p={p} />
                  {i < project.processes.length - 1 && (
                    <div style={{
                      display: "flex", justifyContent: "center", padding: "4px 0",
                    }}>
                      <span style={{ color: DIM, fontSize: 14 }}>↓</span>
                    </div>
                  )}
                </div>
              ))}
            </div>

            {/* Summary bar */}
            <div style={{
              marginTop: 20, padding: 14, borderRadius: 10,
              background: `${RED}10`, border: `1px solid ${RED}30`,
            }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: RED, marginBottom: 4 }}>
                ⚡ Узкое место
              </div>
              <div style={{ fontSize: 13, color: TEXT, lineHeight: 1.5 }}>
                Бэктест ❌ — пока не проверено, реально ли модель зарабатывает.
                Без этого всё остальное не имеет смысла.
              </div>
            </div>
          </div>
        )}

        {/* Bottom hint */}
        <div style={{
          marginTop: 24, textAlign: "center",
          fontSize: 12, color: DIM, lineHeight: 1.6,
        }}>
          Этот формат можно превратить в Forge-скилл.<br />
          Claude Code будет генерировать такую карту для любого проекта.
        </div>
      </div>
    </div>
  );
}
