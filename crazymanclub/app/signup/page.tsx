"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import Link from "next/link";

function makeInternalEmail(loginId: string) {
  return `${loginId.trim().toLowerCase()}@crazymanclub.local`;
}

export default function Signup() {
  const [loginId, setLoginId] = useState("");
  const [password, setPassword] = useState("");
  const [nickname, setNickname] = useState("");
  const [msg, setMsg] = useState("");

  async function signup() {
    const cleanLoginId = loginId.trim().toLowerCase();
    const cleanNickname = nickname.trim();

    if (!/^[a-zA-Z0-9._-]{3,20}$/.test(cleanLoginId)) {
      setMsg("아이디는 영문, 숫자, 점, 언더바, 하이픈만 가능하며 3~20자로 입력해주세요.");
      return;
    }

    if (password.length < 6) {
      setMsg("비밀번호는 최소 6자리 이상 입력해주세요.");
      return;
    }

    if (!cleanNickname) {
      setMsg("캐릭터명 / 닉네임을 입력해주세요.");
      return;
    }

    setMsg("가입 처리 중...");

    const internalEmail = makeInternalEmail(cleanLoginId);

    const { data, error } = await supabase.auth.signUp({
      email: internalEmail,
      password,
    });

    if (error) {
      if (error.message.includes("already registered")) {
        setMsg("이미 사용 중인 아이디입니다.");
      } else {
        setMsg(error.message);
      }
      return;
    }

    if (data.user) {
      const { error: pError } = await supabase.from("profiles").insert({
        id: data.user.id,
        email: internalEmail,
        nickname: cleanNickname,
        role: "member",
        approved: false,
      });

      if (pError) {
        if (pError.message.includes("duplicate")) {
          setMsg("이미 사용 중인 닉네임입니다.");
        } else {
          setMsg(pError.message);
        }
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
          <p>이메일 없이 아이디와 닉네임으로 가입합니다.</p>
        </div>
        <div className="nav">
          <Link href="/">홈</Link>
          <Link href="/login">로그인</Link>
        </div>
      </section>

      <section className="panel">
        <div className="form">
          <label>아이디</label>
          <input
            value={loginId}
            onChange={(e) => setLoginId(e.target.value)}
            placeholder="예: haejun"
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
            placeholder="예: 해준"
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