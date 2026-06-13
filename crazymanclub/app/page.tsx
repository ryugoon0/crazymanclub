"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { MEMBER_NAMES } from "@/lib/members";
import { todayKst } from "@/lib/date";
import Link from "next/link";

type Attendance = {
  nickname: string;
  status: string;
  image_url: string | null;
  created_at: string;
};

export default function Home() {
  const [date, setDate] = useState(todayKst());
  const [rows, setRows] = useState<Attendance[]>([]);
  const [loading, setLoading] = useState(false);

  async function load() {
    setLoading(true);

    const { data } = await supabase
      .from("attendance")
      .select("nickname,status,image_url,created_at")
      .eq("attendance_date", date)
      .order("created_at", { ascending: false });

    setRows(data || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, [date]);

  const done = new Set(
    rows.filter((r) => r.status !== "rejected").map((r) => r.nickname)
  );

  const doneCount = done.size;
  const totalCount = MEMBER_NAMES.length;
  const remainCount = totalCount - doneCount;
  const percent = Math.round((doneCount / totalCount) * 100);

  const shareText =
    `${date.slice(5).replace("-", "/")} 신수교감 출석 현황\n\n` +
    MEMBER_NAMES.map((m, i) => `${done.has(m) ? "✅" : "⬜"} ${i + 1}. ${m}`).join(
      "\n"
    ) +
    `\n\n총 ${doneCount} / ${totalCount} 완료 (${percent}%)`;

  async function copy() {
    await navigator.clipboard.writeText(shareText);
    alert("카카오톡 공유용 출석 현황을 복사했습니다.");
  }

  return (
    <main className="wrap">
      <section className="raidHero">
        <img src="/dragon-raid.jpg" alt="광인회 레이드" />

        <div className="raidOverlay">
          <div className="topNav">
            <div>
              <p className="eyebrow">CrazyManClub</p>
              <h1>광인회 신수교감</h1>
              <p className="heroDesc">오늘의 레이드 참여 현황</p>
            </div>

            <div className="nav">
              <Link href="/login">로그인</Link>
              <Link href="/signup">회원가입</Link>
              <Link href="/upload">출석하기</Link>
              <Link href="/admin">운영진</Link>
            </div>
          </div>

          <div className="heroBottom">
            <div>
              <span className="raidLabel">현재 참여</span>
              <strong>
                {doneCount} / {totalCount}
              </strong>
              <div className="raidProgress">
                <div style={{ width: `${percent}%` }} />
              </div>
            </div>

            <div className="percentBadge">
              <span>{percent}%</span>
              <small>공략률</small>
            </div>
          </div>
        </div>
      </section>

      <section className="raidSummary">
        <div className="raidCard">
          <span>완료 인원</span>
          <strong>{doneCount}명</strong>
        </div>

        <div className="raidCard">
          <span>미완료 인원</span>
          <strong>{remainCount}명</strong>
        </div>

        <div className="raidCard">
          <span>오늘 공략률</span>
          <strong>{percent}%</strong>
        </div>
      </section>

      <section className="panel">
        <div className="dateRow">
          <div>
            <h2>날짜별 출석판</h2>
            <p className="muted">날짜를 선택하면 해당 일자의 출석 현황을 확인할 수 있습니다.</p>
          </div>

          <div className="dateControls">
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
            <button className="secondary" onClick={copy}>
              카카오톡 공유용 복사
            </button>
          </div>
        </div>
      </section>

      <section className="grid">
        <section className="panel">
          <div className="sectionTitle">
            <div>
              <h2>출석 현황</h2>
              <p className="muted">
                {loading ? "불러오는 중..." : `${doneCount} / ${totalCount} 완료`}
              </p>
            </div>
            <span className="pill">{percent}%</span>
          </div>

          <div className="cards">
            {MEMBER_NAMES.map((m, i) => (
              <div className={`member ${done.has(m) ? "done" : "pending"}`} key={m}>
                <div>
                  <small>{String(i + 1).padStart(2, "0")}</small>
                  <strong>{m}</strong>
                </div>
                <span className="badge">{done.has(m) ? "참여" : "대기"}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <div className="sectionTitle">
            <div>
              <h2>카카오톡 공유용</h2>
              <p className="muted">복사해서 채팅방에 바로 붙여넣을 수 있습니다.</p>
            </div>
          </div>

          <pre>{shareText}</pre>
        </section>
      </section>
    </main>
  );
}