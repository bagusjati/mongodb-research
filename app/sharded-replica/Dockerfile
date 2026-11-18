FROM golang:1.19-bullseye

WORKDIR /app

COPY . .

RUN go mod tidy && go build -o /app/main .

EXPOSE 8080

CMD ["/app/main"]
