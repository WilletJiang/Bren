package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"bren/internal/appserver"
	"bren/internal/protocol"
	"bren/internal/translation"
	"bren/internal/transport"
)

func main() {
	var codexPath string
	var model string
	var serviceTier string
	flag.StringVar(&codexPath, "codex", os.Getenv("BREN_CODEX_PATH"), "path to the Codex CLI executable")
	flag.StringVar(&model, "model", "gpt-5.6-luna", "Codex model used for translation")
	flag.StringVar(&serviceTier, "service-tier", "", "optional Codex service tier")
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	client, err := appserver.Start(ctx, appserver.Config{
		CodexPath:   codexPath,
		Model:       model,
		ServiceTier: serviceTier,
	})
	if err != nil {
		_ = json.NewEncoder(os.Stdout).Encode(protocol.NewError("", "backend_start_failed", err.Error(), true))
		fmt.Fprintln(os.Stderr, "bren-core:", err)
		os.Exit(1)
	}
	defer client.Close()
	service := translation.New(client)
	server := transport.New(service, client.Model())
	if err := server.Serve(ctx, os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "bren-core:", err)
		os.Exit(1)
	}
}
