"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import Link from "next/link";

export default function Signup() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nickname, setNickname] = useState("");
  const [msg, setMsg] = useState("");

  async function signup() {
    const cleanNickname = nickname.trim();

    if (!email.trim()) {
      setMsg("이메일을 입력해주세요.");
      return;
    }

    if (password.length < 6) {
      setMsg("비밀번호는 최소 6자리 이상 입력해주세요.");
      return;
    }

    if (!cleanNickname) {
      setMsg("닉네임을 입력해주세요.");
      return;
    }

    setMsg("가입 처리 중...");

    const { data, error } = await supabase.auth.signUp({
      email: email.trim(),
      password,
    });

    if (error) {
      setMsg(error.message);
      return;
    }

    if (data.user) {
      const { error: pError } = await supabase.from("profiles").insert({
        id: data.user.id,
        email: email.trim(),
        nickname: cleanNickname,
        role: "member",
        approved: false,
      });

      if (pError) {
        setMsg(pError.message);
      } else {
        setMsg("가입 완료. 운영진 승인 후 사용 가능합니다.");
      }
    }
  }

  return (
    <main className="wrap">
      <section className="header">
        <div>
          <h1>회원가입</h1>
          <p>가입 시 입력한 닉네임으로 출석판에 자동 표시됩니다.</p>
        </div>
        <div className="nav">
          <Link href="/">홈</Link>
          <Link href="/login">로그인</Link>
        </div>
      </section>

      <section className="panel">
        <div className="form">
          <label>이메일</label>
          <input
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="email@example.com"
          />

          <label>비밀번호</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="6자리 이상"
          />

          <label>캐릭터명 / 닉네임</label>
          <input
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            placeholder="예: 우댕, 킬러, 리오"
          />

          <button className="primary" onClick={signup}>
            회원가입
          </button>

          {msg && <div className="notice">{msg}</div>}
        </div>
      </section>
    </main>
  );
}