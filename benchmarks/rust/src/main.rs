use logos::Logos;
use std::{env, hint::black_box};

const LINE: &str = include_str!("../../lexer_compare_input.txt");

#[derive(Debug, Logos)]
#[logos(skip r"[ \t\r\n]+")]
enum Token {
    #[token("let")]
    Let,
    #[token("=")]
    Equals,
    #[token(";")]
    Semicolon,
    #[regex("[A-Za-z_][A-Za-z0-9_]*")]
    Identifier,
    #[regex("[0-9]+")]
    Integer,
}

fn main() {
    let mut args = env::args().skip(1);
    if args.next().as_deref() == Some("--spans") {
        for source in args {
            for (result, span) in Token::lexer(&source).spanned() {
                match result {
                    Ok(token) => println!("{token:?}@{}...{}", span.start, span.end),
                    Err(()) => println!("error@{}...{}", span.start, span.end),
                }
            }
            println!("EOF");
        }
        return;
    }

    let rounds = env::var("LOGOS_BENCH_ROUNDS")
        .unwrap_or_else(|_| "10".into())
        .parse::<usize>()
        .expect("LOGOS_BENCH_ROUNDS must be a nonnegative integer");
    let source = LINE.repeat(1_000);
    let count: usize = (0..rounds)
        .map(|_| Token::lexer(black_box(source.as_str())).count())
        .sum();
    println!("{count}");
}
