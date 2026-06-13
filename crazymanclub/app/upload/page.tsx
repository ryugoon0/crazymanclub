"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { todayKst } from "@/lib/date";
import Link from "next/link";
import { useRouter } from "next/navigation";

type Member = {
  id: number;
  login_id: string;
  nickname: string;
  role: string;
  approved: boolean;
};

export default function Upload() {
  const [member, setMember] = useState<Member | null>(null);
  const [date, setDate] = useState(todayKst());
  const [file, setFile] = useState<File | null>(null);
  const [msg, setMsg] = useState("");
  const router = useRouter();

  useEffect(() => {
    const saved = localStorage.getItem("cmc_member");

    if (!saved) {
      router.push("/login");
      return;
    }

    setMember(JSON.parse(saved));
  }, [router]);

  async function upload() {
    if (!member) return;

    if (!member.approved) {
      setMsg("운영진 승인 후 출석 가능합니다.");
      return;
    }

    if (!file) {
      setMsg("스크린샷을 선택해주세요.");
      return;
    }

    setMsg("업로드 중...");

    const ext = file.name.split(".").pop() || "jpg";
    const path = `${date}/${member.nickname}-${Date.now()}.${ext}`;

    const { error: upError } = await supabase.storage
      .from("attendance-images")
      .upload(path, file, {
        cacheControl: "3600",
        upsert: true,
      });

    if (upError) {
      setMsg(upError.message);
      return;
    }

    const { data: pub } = supabase.storage
      .from("attendance-images")
      .getPublicUrl(path);

    const imageUrl = pub.publicUrl;

    const { error } = await supabase.from("attendance").upsert(
      {
        member_id: member.id,
        nickname: member.nickname,
        attendance_date: date,
        image_url: imageUrl,
        status: "submitted",
      },
      { onConflict: "member_id,attendance_date" }
    );

    if (error) {
      setMsg(error.message);
    } else {
      setMsg(`${member.nickname} 님 ${date} 출석 완료`);
    }
  }

  function logout() {
    localStorage.removeItem("cmc_member");
    router.push("/");
  }

  return (
    <main className="wrap">
      <section className="header">
        <div>
          <h1>스크린샷 출석</h1>
          <p>로그인 계정의 닉네임으로 자동 출석됩니다.</p>
        </div>
        <div className="nav">
          <Link href="/">홈</Link>
          <Link href="/admin">운영진</Link>
          <button onClick={logout}>로그아웃</button>
        </div>
      </section>

      <section className="panel">
        {!member ? (
          <p>확인 중...</p>
        ) : (
          <div className="form">
            <div className="notice">
              로그인 닉네임: <b>{member.nickname}</b>
              <br />
              승인상태: <b>{member.approved ? "승인됨" : "승인 대기"}</b>
            </div>

            <label>출석일</label>
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />

            <label>신수교감 스크린샷</label>
            <input
              type="file"
              accept="image/*"
              onChange={(e) => setFile(e.target.files?.[0] || null)}
            />

            <button className="primary" onClick={upload}>
              출석 제출
            </button>

            {msg && <div className="notice">{msg}</div>}
          </div>
        )}
      </section>
    </main>
  );
}