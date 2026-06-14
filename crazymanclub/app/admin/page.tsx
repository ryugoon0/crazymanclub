"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { todayKst } from "@/lib/date";
import Link from "next/link";
import { useRouter } from "next/navigation";

type Member = {
  id: number;
  login_id: string;
  password: string;
  nickname: string;
  role: string;
  approved: boolean;
  created_at: string;
};

type Attendance = {
  id: string;
  member_id: number;
  nickname: string;
  attendance_date: string;
  image_url: string | null;
  status: string;
  created_at: string;
};

export default function Admin() {
  const [me, setMe] = useState<Member | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [logs, setLogs] = useState<Attendance[]>([]);
  const [date, setDate] = useState(todayKst());
  const [msg, setMsg] = useState("");
  const router = useRouter();

  useEffect(() => {
    const saved = localStorage.getItem("cmc_member");

    if (!saved) {
      router.push("/login");
      return;
    }

    const member = JSON.parse(saved) as Member;
    setMe(member);

    if (member.role !== "admin") {
      setMsg("운영진 권한이 필요합니다.");
      return;
    }

    loadAdminData();
  }, [router]);

  useEffect(() => {
    if (me?.role === "admin") {
      loadAdminData();
    }
  }, [date, me]);

  async function loadAdminData() {
    const { data: memberData, error: memberError } = await supabase
      .from("members")
      .select("*")
      .order("created_at", { ascending: false });

    if (memberError) {
      setMsg(memberError.message);
      return;
    }

    const { data: logData, error: logError } = await supabase
      .from("attendance")
      .select("*")
      .eq("attendance_date", date)
      .order("created_at", { ascending: false });

    if (logError) {
      setMsg(logError.message);
      return;
    }

    setMembers(memberData || []);
    setLogs(logData || []);
  }

  async function approveMember(id: number, approved: boolean) {
    const { error } = await supabase
      .from("members")
      .update({ approved })
      .eq("id", id);

    if (error) {
      alert(error.message);
      return;
    }

    await loadAdminData();
  }

  async function changeRole(id: number, role: string) {
    const { error } = await supabase.from("members").update({ role }).eq("id", id);

    if (error) {
      alert(error.message);
      return;
    }

    await loadAdminData();
  }

  async function setStatus(id: string, status: string) {
    const { error } = await supabase
      .from("attendance")
      .update({ status })
      .eq("id", id);

    if (error) {
      alert(error.message);
      return;
    }

    await loadAdminData();
  }

  function logout() {
    localStorage.removeItem("cmc_member");
    router.push("/");
  }

  const pendingMembers = members.filter((m) => !m.approved);
  const approvedMembers = members.filter((m) => m.approved);
  const validLogs = logs.filter((l) => l.status !== "rejected");
  const doneNicknames = new Set(validLogs.map((l) => l.nickname));

  const totalCount = approvedMembers.length;
  const doneCount = doneNicknames.size;
  const remainCount = Math.max(totalCount - doneCount, 0);
  const percent = totalCount === 0 ? 0 : Math.round((doneCount / totalCount) * 100);

  return (
    <main className="wrap">
      <section className="header">
        <div>
          <h1>운영진 관리</h1>
          <p>회원 승인, 출석 현황, 스크린샷 로그를 관리합니다.</p>
        </div>

        <div className="nav">
          <Link href="/">홈</Link>
          <Link href="/upload">출석하기</Link>
          <button onClick={logout}>로그아웃</button>
        </div>
      </section>

      {msg && <section className="panel notice">{msg}</section>}

      {me?.role === "admin" && (
        <>
          <section className="panel">
            <div className="sectionTitle">
              <div>
                <h2>승인 대기 회원</h2>
                <p className="muted">회원가입 후 승인 대기 중인 인원입니다.</p>
              </div>
              <span className="pill">{pendingMembers.length}명</span>
            </div>

            {pendingMembers.length === 0 ? (
              <div className="notice">승인 대기 회원이 없습니다.</div>
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th>닉네임</th>
                    <th>아이디</th>
                    <th>가입일</th>
                    <th>처리</th>
                  </tr>
                </thead>
                <tbody>
                  {pendingMembers.map((member) => (
                    <tr key={member.id}>
                      <td>{member.nickname}</td>
                      <td>{member.login_id}</td>
                      <td>{new Date(member.created_at).toLocaleString("ko-KR")}</td>
                      <td>
                        <button
                          className="secondary"
                          onClick={() => approveMember(member.id, true)}
                        >
                          승인하기
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>

          <section className="raidSummary">
            <div className="raidCard">
              <span>출석 완료</span>
              <strong>{doneCount}명</strong>
            </div>
            <div className="raidCard">
              <span>미완료</span>
              <strong>{remainCount}명</strong>
            </div>
            <div className="raidCard">
              <span>출석률</span>
              <strong>{percent}%</strong>
            </div>
          </section>

          <section className="panel">
            <div className="dateRow">
              <div>
                <h2>날짜별 출석 현황</h2>
                <p className="muted">조회할 날짜를 선택하세요.</p>
              </div>

              <div className="dateControls">
                <input
                  type="date"
                  value={date}
                  onChange={(e) => setDate(e.target.value)}
                />
                <button className="secondary" onClick={loadAdminData}>
                  새로고침
                </button>
              </div>
            </div>
          </section>

          <section className="grid">
            <section className="panel">
              <div className="sectionTitle">
                <div>
                  <h2>출석판</h2>
                  <p className="muted">
                    승인된 회원 기준 {doneCount} / {totalCount} 완료
                  </p>
                </div>
                <span className="pill">{percent}%</span>
              </div>

              <div className="cards">
                {approvedMembers.map((member, i) => {
                  const done = doneNicknames.has(member.nickname);

                  return (
                    <div
                      key={member.id}
                      className={`member ${done ? "done" : "pending"}`}
                    >
                      <div>
                        <small>{String(i + 1).padStart(2, "0")}</small>
                        <strong>{member.nickname}</strong>
                      </div>

                      <span className="badge">{done ? "참여" : "대기"}</span>
                    </div>
                  );
                })}
              </div>
            </section>

            <section className="panel">
              <div className="sectionTitle">
                <div>
                  <h2>회원 관리</h2>
                  <p className="muted">전체 회원 승인 상태와 권한을 관리합니다.</p>
                </div>
              </div>

              <table className="table">
                <thead>
                  <tr>
                    <th>닉네임</th>
                    <th>아이디</th>
                    <th>승인</th>
                    <th>권한</th>
                  </tr>
                </thead>

                <tbody>
                  {members.map((member) => (
                    <tr key={member.id}>
                      <td>{member.nickname}</td>
                      <td>{member.login_id}</td>
                      <td>
                        <button
                          className="secondary"
                          onClick={() =>
                            approveMember(member.id, !member.approved)
                          }
                        >
                          {member.approved ? "승인 취소" : "승인하기"}
                        </button>
                      </td>
                      <td>
                        <button
                          className="secondary"
                          onClick={() =>
                            changeRole(
                              member.id,
                              member.role === "admin" ? "member" : "admin"
                            )
                          }
                        >
                          {member.role === "admin" ? "운영진" : "일반"}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          </section>

          <section className="panel">
            <div className="sectionTitle">
              <div>
                <h2>스크린샷 로그</h2>
                <p className="muted">업로드된 인증샷을 확인하고 승인/반려 처리합니다.</p>
              </div>
            </div>

            {logs.length === 0 ? (
              <div className="notice">해당 날짜의 스크린샷 로그가 없습니다.</div>
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th>시간</th>
                    <th>닉네임</th>
                    <th>상태</th>
                    <th>이미지</th>
                    <th>처리</th>
                  </tr>
                </thead>

                <tbody>
                  {logs.map((log) => (
                    <tr key={log.id}>
                      <td>{new Date(log.created_at).toLocaleString("ko-KR")}</td>
                      <td>{log.nickname}</td>
                      <td>{log.status}</td>
                      <td>
                        {log.image_url ? (
                          <a href={log.image_url} target="_blank">
                            <img
                              className="thumb"
                              src={log.image_url}
                              alt="screenshot"
                            />
                          </a>
                        ) : (
                          "수동 처리"
                        )}
                      </td>
                      <td>
                        <button
                          className="secondary"
                          onClick={() => setStatus(log.id, "approved")}
                        >
                          승인
                        </button>{" "}
                        <button
                          className="secondary"
                          onClick={() => setStatus(log.id, "rejected")}
                        >
                          반려
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>
        </>
      )}
    </main>
  );
}