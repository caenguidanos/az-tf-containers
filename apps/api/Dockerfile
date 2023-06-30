FROM rust:1.70.0 as builder
WORKDIR /usr/src/app
COPY . .
RUN cargo build --release

FROM gcr.io/distroless/cc
COPY --from=builder /usr/src/app/target/release/api /
EXPOSE 8080
ENTRYPOINT ["./api"]