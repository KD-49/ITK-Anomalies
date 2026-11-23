--!strict
-- InvestigationService.luau
-- Service Server untuk menangani aktivitas investigasi di Gedung A dan Gedung B.
-- Saat ini menyediakan fondasi struktural untuk pelacakan objektif dan pengumpulan bukti (evidence)
-- yang siap dihubungkan ke objek 3D Gedung A & Gedung B saat pembangunannya selesai.

local InvestigationService = {}

export type EvidenceRecord = {
	id: string,
	building: "Gedung A" | "Gedung B" | "Pos Satpam",
	title: string,
	collected: boolean,
}

local collectedEvidence: { [string]: boolean } = {}
local totalCollectedCount = 0

function InvestigationService.Init()
	InvestigationService.ResetForShift()
end

function InvestigationService.ResetForShift()
	collectedEvidence = {}
	totalCollectedCount = 0
end

function InvestigationService.CollectEvidence(evidenceId: string): boolean
	if type(evidenceId) ~= "string" or evidenceId == "" then
		return false
	end
	if collectedEvidence[evidenceId] then
		return false
	end

	collectedEvidence[evidenceId] = true
	totalCollectedCount += 1
	return true
end

function InvestigationService.GetProgressSummary(): { collectedCount: number }
	return {
		collectedCount = totalCollectedCount,
	}
end

return InvestigationService
